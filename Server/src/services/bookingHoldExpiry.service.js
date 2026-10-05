import Stripe from "stripe";

import {
  BOOKING_HOLD_CLAIM_TIMEOUT_MS,
  BOOKING_HOLD_RETENTION_MS,
  BOOKING_HOLD_SWEEP_BATCH_SIZE,
  BOOKING_HOLD_SWEEP_INTERVAL_MS,
} from "../config/bookingHold.js";
import { captureServerFailure } from "../config/sentry.js";
import BookingHold from "../models/bookingHold.js";

let sweepRunning = false;

const stripeClient = () => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error("STRIPE_SECRET_KEY is not configured");
  }

  return new Stripe(process.env.STRIPE_SECRET_KEY);
};

const claimExpiredHold = () => {
  const now = new Date();
  const staleClaim = new Date(Date.now() - BOOKING_HOLD_CLAIM_TIMEOUT_MS);

  return BookingHold.findOneAndUpdate(
    {
      expiresAt: { $lte: now },
      $or: [
        { status: "Active" },
        {
          status: "Expiring",
          expiryClaimedAt: { $lte: staleClaim },
        },
        {
          status: "Expiring",
          expiryClaimedAt: null,
        },
      ],
    },
    {
      $set: {
        status: "Expiring",
        expiryClaimedAt: now,
      },
      $unset: { lastExpiryError: 1 },
    },
    {
      new: true,
      sort: { expiresAt: 1 },
    }
  );
};

const markHoldExpired = (holdId) =>
  BookingHold.updateOne(
    { _id: holdId, status: "Expiring" },
    {
      $set: {
        status: "Expired",
        purgeAt: new Date(Date.now() + BOOKING_HOLD_RETENTION_MS),
      },
      $unset: {
        expiryClaimedAt: 1,
        lastExpiryError: 1,
      },
    }
  );

const recordExpiryFailure = (holdId, error) =>
  BookingHold.updateOne(
    { _id: holdId, status: "Expiring" },
    {
      $set: {
        lastExpiryError: (error?.message || "Unknown expiration error").slice(
          0,
          500
        ),
      },
    }
  );

const expireClaimedHold = async (stripe, hold) => {
  if (!hold.paymentIntentId) {
    await markHoldExpired(hold._id);
    return;
  }

  let intent;
  try {
    intent = await stripe.paymentIntents.retrieve(hold.paymentIntentId);
  } catch (error) {
    if (error?.code === "resource_missing") {
      await markHoldExpired(hold._id);
      return;
    }
    throw error;
  }

  if (intent.status === "succeeded") {
    // Payment and expiration can happen at nearly the same instant. Refund is
    // idempotent and remains the final protection for that unavoidable race.
    await stripe.refunds.create(
      { payment_intent: intent.id },
      { idempotencyKey: `diamondcar-unavailable-refund-${intent.id}` }
    );
    await stripe.paymentIntents.update(intent.id, {
      metadata: { bookingOutcome: "refunded_hold_expired" },
    });
  } else if (intent.status !== "canceled") {
    await stripe.paymentIntents.cancel(intent.id, {
      cancellation_reason: "abandoned",
    });
  }

  await markHoldExpired(hold._id);
};

export const runBookingHoldExpirySweep = async () => {
  if (sweepRunning || !process.env.STRIPE_SECRET_KEY) return;

  sweepRunning = true;
  try {
    const stripe = stripeClient();

    for (let index = 0; index < BOOKING_HOLD_SWEEP_BATCH_SIZE; index += 1) {
      const hold = await claimExpiredHold();
      if (!hold) break;

      try {
        await expireClaimedHold(stripe, hold);
      } catch (error) {
        await recordExpiryFailure(hold._id, error);
        captureServerFailure(error, "booking-hold-expiry");
        console.error(
          `Could not expire booking hold ${hold._id}:`,
          error.message
        );
      }
    }
  } catch (error) {
    captureServerFailure(error, "booking-hold-expiry-sweep");
    console.error("Booking hold expiration sweep failed:", error.message);
  } finally {
    sweepRunning = false;
  }
};

export const startBookingHoldExpiryWorker = () => {
  if (!process.env.STRIPE_SECRET_KEY) {
    console.warn(
      "Booking hold expiration worker disabled: STRIPE_SECRET_KEY is missing"
    );
    return () => {};
  }

  void runBookingHoldExpirySweep();
  const timer = setInterval(
    () => void runBookingHoldExpirySweep(),
    BOOKING_HOLD_SWEEP_INTERVAL_MS
  );
  timer.unref?.();

  console.log(
    `Booking hold expiration worker running every ${
      BOOKING_HOLD_SWEEP_INTERVAL_MS / 1000
    } seconds`
  );

  return () => clearInterval(timer);
};
