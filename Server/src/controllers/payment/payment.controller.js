import { randomUUID } from "node:crypto";

import mongoose from "mongoose";
import Stripe from "stripe";

import {
  BOOKING_HOLD_DURATION_MS,
  BOOKING_HOLD_RETENTION_MS,
} from "../../config/bookingHold.js";
import Booking from "../../models/booking.js";
import BookingHold from "../../models/bookingHold.js";
import CarVariant from "../../models/carVariant.js";
import Payment from "../../models/payment.js";
import Renter from "../../models/renter.js";
import { notifyBookingConfirmed } from "../../services/notification.service.js";

const stripeClient = () => {
  const secretKey = process.env.STRIPE_SECRET_KEY;

  if (!secretKey) {
    const error = new Error("STRIPE_SECRET_KEY is not configured");
    error.statusCode = 500;
    throw error;
  }

  return new Stripe(secretKey);
};

const parseRentalDates = (startValue, endValue) => {
  const startDate = new Date(startValue);
  const endDate = new Date(endValue);
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
    return { error: "Start date and end date must be valid dates" };
  }

  if (startDate < today) {
    return { error: "Pickup date cannot be in the past" };
  }

  if (endDate <= startDate) {
    return { error: "Return date must be after pickup date" };
  }

  return {
    startDate,
    endDate,
    days: Math.ceil((endDate - startDate) / 86_400_000),
  };
};

// Inclusive date-only boundaries prevent same-day handover between renters.
const bookingConflictQuery = (carVariant, startDate, endDate) => ({
  carVariant,
  status: { $in: ["Confirmed", "InProgress"] },
  startDate: { $lte: endDate },
  endDate: { $gte: startDate },
});

const isPubliclyListed = (variant) =>
  variant.isAvailable === true &&
  (variant.approvalStatus ?? "Approved") === "Approved" &&
  !variant.archivedAt;

const blockingHoldConflictQuery = (
  carVariant,
  startDate,
  endDate
) => ({
  carVariant,
  startDate: { $lte: endDate },
  endDate: { $gte: startDate },
  status: { $in: ["Active", "Expiring"] },
});

const releaseBookingHold = async (holdId, status = "Cancelled") => {
  if (!holdId) return;

  await BookingHold.updateOne(
    { _id: holdId, status: "Active" },
    {
      $set: {
        status,
        purgeAt: new Date(Date.now() + BOOKING_HOLD_RETENTION_MS),
      },
    }
  );
};

const acquireBookingHold = async ({ renterId, carVariantId, dates }) => {
  const session = await mongoose.startSession();
  const checkoutReference = randomUUID();
  const expiresAt = new Date(Date.now() + BOOKING_HOLD_DURATION_MS);
  const purgeAt = new Date(Date.now() + BOOKING_HOLD_RETENTION_MS);
  let hold;
  let variant;

  try {
    await session.withTransaction(async () => {
      // Every checkout for this vehicle writes to the same document. MongoDB
      // therefore forces simultaneous transactions to run one after another.
      variant = await CarVariant.findOneAndUpdate(
        {
          _id: carVariantId,
          isAvailable: true,
          archivedAt: null,
          $or: [
            { approvalStatus: "Approved" },
            { approvalStatus: { $exists: false } },
          ],
        },
        { $inc: { reservationVersion: 1 } },
        { new: true, session }
      ).populate("provider");

      if (!variant) {
        const error = new Error("This vehicle is not currently listed for renters");
        error.statusCode = 409;
        error.code = "VEHICLE_NOT_LISTED";
        throw error;
      }

      if (!variant.provider) {
        const error = new Error("Car provider is missing");
        error.statusCode = 400;
        throw error;
      }

      // Do not run operations concurrently on the same MongoDB transaction.
      const bookingConflict = await Booking.exists(
        bookingConflictQuery(carVariantId, dates.startDate, dates.endDate)
      ).session(session);
      const holdConflict = await BookingHold.exists(
        blockingHoldConflictQuery(
          carVariantId,
          dates.startDate,
          dates.endDate
        )
      ).session(session);

      if (bookingConflict || holdConflict) {
        const error = new Error(
          holdConflict
            ? "This vehicle is temporarily reserved for those dates. Please try again shortly."
            : "Car is already booked for those dates"
        );
        error.statusCode = 409;
        error.code = holdConflict ? "HOLD_CONFLICT" : "BOOKING_CONFLICT";
        throw error;
      }

      const rentalSubtotal = dates.days * variant.rentalPricePerDay;
      const depositAmount = variant.depositAmount || 0;
      const totalAmount = rentalSubtotal + depositAmount;

      [hold] = await BookingHold.create(
        [
          {
            renter: renterId,
            provider: variant.provider._id,
            carVariant: variant._id,
            startDate: dates.startDate,
            endDate: dates.endDate,
            days: dates.days,
            dailyRate: variant.rentalPricePerDay,
            rentalSubtotal,
            depositAmount,
            totalAmount,
            currency: "AED",
            checkoutReference,
            expiresAt,
            purgeAt,
          },
        ],
        { session }
      );
    });

    return { hold, variant };
  } finally {
    await session.endSession();
  }
};

const findRenter = async (renterId) => {
  if (!mongoose.isValidObjectId(renterId)) {
    const error = new Error("Invalid renter ID");
    error.statusCode = 400;
    throw error;
  }

  const renter = await Renter.findById(renterId);
  if (!renter) {
    const error = new Error("Renter not found");
    error.statusCode = 404;
    throw error;
  }

  return renter;
};

const getOrCreateStripeCustomer = async (stripe, renter) => {
  if (renter.stripeCustomerId) {
    try {
      const customer = await stripe.customers.retrieve(
        renter.stripeCustomerId
      );

      if (!customer.deleted) return customer;
    } catch (error) {
      if (error?.code !== "resource_missing") throw error;
    }
  }

  const customer = await stripe.customers.create(
    {
      name: renter.name,
      email: renter.email,
      metadata: { renterId: renter._id.toString() },
    },
    { idempotencyKey: `diamondcar-renter-${renter._id}` }
  );

  renter.stripeCustomerId = customer.id;
  await renter.save();
  return customer;
};

const createMobileCustomerSession = (stripe, customerId) =>
  stripe.customerSessions.create({
    customer: customerId,
    components: {
      mobile_payment_element: {
        enabled: true,
        features: {
          // The app already has its own "Save a new card" checkbox.
          payment_method_save: "disabled",

          // Cards saved after explicit consent can be displayed again.
          payment_method_save_allow_redisplay_override: "always",

          // Allow the renter to select previously saved cards.
          payment_method_redisplay: "enabled",

          // Include older cards whose allow_redisplay was not previously set.
          payment_method_allow_redisplay_filters: [
            "always",
            "limited",
            "unspecified",
          ],

          // Removal is handled safely from your Payment Methods page.
          payment_method_remove: "disabled",
        },
      },
    },
  });

export const createStripePaymentIntent = async (req, res) => {
  const {
    renter,
    carVariant,
    startDate: startValue,
    endDate: endValue,
    savePaymentMethod = false,
  } = req.body;

  if (!renter || !carVariant || !startValue || !endValue) {
    return res.status(400).json({
      message: "All required fields must be filled",
    });
  }

  const dates = parseRentalDates(startValue, endValue);
  if (dates.error) {
    return res.status(400).json({ message: dates.error });
  }

  if (!mongoose.isValidObjectId(carVariant)) {
    return res.status(400).json({ message: "Invalid car variant ID" });
  }

  let stripeIntent;
  let bookingHold;

  try {
    const existingRenter = await findRenter(renter);
    const acquired = await acquireBookingHold({
      renterId: existingRenter._id,
      carVariantId: carVariant,
      dates,
    });
    bookingHold = acquired.hold;
    const variant = acquired.variant;
    const amountInFils = Math.round(bookingHold.totalAmount * 100);

    if (amountInFils < 200) {
      const error = new Error("Payment amount is too small");
      error.statusCode = 400;
      throw error;
    }

    const stripe = stripeClient();
    const customer = await getOrCreateStripeCustomer(stripe, existingRenter);
    const customerSession = await createMobileCustomerSession(
      stripe,
      customer.id
    );
    stripeIntent = await stripe.paymentIntents.create(
      {
        amount: amountInFils,
        currency: "aed",
        customer: customer.id,
        payment_method_types: ["card"],
        ...(savePaymentMethod === true && {
          setup_future_usage: "on_session",
        }),
        description: `DiamondCar rental ${bookingHold.checkoutReference}`,
        metadata: {
          bookingHoldId: bookingHold._id.toString(),
          checkoutReference: bookingHold.checkoutReference,
          renterId: existingRenter._id.toString(),
          providerId: variant.provider._id.toString(),
          carVariantId: variant._id.toString(),
          startDate: bookingHold.startDate.toISOString(),
          endDate: bookingHold.endDate.toISOString(),
          days: bookingHold.days.toString(),
          rentalSubtotal: bookingHold.rentalSubtotal.toString(),
          depositAmount: bookingHold.depositAmount.toString(),
          totalAmount: bookingHold.totalAmount.toString(),
          bookingOutcome: "awaiting_payment",
        },
      },
      {
        idempotencyKey: `diamondcar-payment-${bookingHold.checkoutReference}`,
      }
    );

    const attachedHold = await BookingHold.findOneAndUpdate(
      {
        _id: bookingHold._id,
        status: "Active",
        expiresAt: { $gt: new Date() },
      },
      { $set: { paymentIntentId: stripeIntent.id } },
      { new: true, runValidators: true }
    );

    if (!attachedHold) {
      const error = new Error(
        "The temporary reservation expired before payment could start. Please try again."
      );
      error.statusCode = 409;
      error.code = "HOLD_EXPIRED";
      throw error;
    }
    bookingHold = attachedHold;

    return res.status(201).json({
      clientSecret: stripeIntent.client_secret,
      paymentIntentId: stripeIntent.id,
      customerId: customer.id,
      customerSessionClientSecret: customerSession.client_secret,
      bookingHoldId: bookingHold._id,
      holdExpiresAt: bookingHold.expiresAt,
      holdDurationSeconds: Math.floor(BOOKING_HOLD_DURATION_MS / 1000),
      pricing: {
        days: bookingHold.days,
        dailyRate: bookingHold.dailyRate,
        rentalSubtotal: bookingHold.rentalSubtotal,
        depositAmount: bookingHold.depositAmount,
        totalAmount: bookingHold.totalAmount,
        currency: "AED",
      },
    });
  } catch (error) {
    if (stripeIntent) {
      try {
        await stripeClient().paymentIntents.cancel(stripeIntent.id, {
          cancellation_reason: "abandoned",
        });
      } catch (cancelError) {
        console.error("Could not cancel orphaned PaymentIntent:", cancelError);
      }
    }

    try {
      await releaseBookingHold(bookingHold?._id);
    } catch (releaseError) {
      console.error("Could not release failed booking hold:", releaseError);
    }

    console.error("Create Stripe PaymentIntent error:", error);
    return res.status(error.statusCode || 500).json({
      message:
        error.statusCode && error.statusCode < 500
          ? error.message
          : "Could not start Stripe payment",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

export const getStripePaymentStatus = async (req, res) => {
  try {
    const { paymentIntentId } = req.params;

    if (!paymentIntentId?.startsWith("pi_")) {
      return res.status(400).json({ message: "Invalid payment intent ID" });
    }

    const [intent, payment] = await Promise.all([
      stripeClient().paymentIntents.retrieve(paymentIntentId),
      Payment.findOne({ stripePaymentIntentId: paymentIntentId }),
    ]);

    // The Payment document is created by the webhook, so it may not exist yet
    // when Flutter starts polling. Stripe metadata is therefore the reliable
    // ownership source during this short interval.
    if (
      req.auth?.type !== "Admin" &&
      intent.metadata?.renterId !== req.auth?.userId
    ) {
      return res.status(404).json({ message: "Payment intent not found" });
    }

    const booking = payment
      ? await Booking.findOne({ payment: payment._id }).select("_id status")
      : null;

    const outcome = intent.metadata?.bookingOutcome;
    const refundedBecauseUnavailable = [
      "refunded_unavailable",
      "refunded_hold_expired",
    ].includes(outcome);

    return res.status(200).json({
      paymentIntentId,
      stripeStatus: intent.status,
      paymentStatus:
        payment?.paymentStatus ??
        (refundedBecauseUnavailable
          ? "Refunded"
          : intent.status === "succeeded"
            ? "Processing"
            : intent.status),
      bookingId: booking?._id ?? null,
      bookingStatus: booking?.status ?? null,
      confirmed:
        payment?.paymentStatus === "Completed" &&
        ["Confirmed", "InProgress", "Completed"].includes(booking?.status),
      refunded: refundedBecauseUnavailable || payment?.paymentStatus === "Refunded",
      message: refundedBecauseUnavailable
        ? outcome === "refunded_hold_expired"
          ? "The temporary reservation expired before payment completed. Your payment was refunded."
          : "Those dates became unavailable during payment. Your payment was refunded."
        : undefined,
    });
  } catch (error) {
    const statusCode = error?.code === "resource_missing" ? 404 : 500;
    return res.status(statusCode).json({
      message:
        statusCode === 404
          ? "Payment intent not found"
          : "Could not load payment status",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

const detectPaymentMethod = async (stripe, intent) => {
  if (!intent.latest_charge) return "Card";

  try {
    const chargeId =
      typeof intent.latest_charge === "string"
        ? intent.latest_charge
        : intent.latest_charge.id;
    const charge = await stripe.charges.retrieve(chargeId);
    const walletType = charge.payment_method_details?.card?.wallet?.type;

    if (walletType === "apple_pay") return "Apple Pay";
    if (walletType === "google_pay") return "Google Pay";
    if (walletType === "link") return "Link";
    return "Card";
  } catch {
    return "Card";
  }
};

const refundUnavailablePayment = async (
  stripe,
  intent,
  bookingOutcome = "refunded_unavailable"
) => {
  await stripe.refunds.create(
    { payment_intent: intent.id },
    { idempotencyKey: `diamondcar-unavailable-refund-${intent.id}` }
  );

  await stripe.paymentIntents.update(intent.id, {
    metadata: { bookingOutcome },
  });
};

export const stripeWebhook = async (req, res) => {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return res.status(500).send("STRIPE_WEBHOOK_SECRET is not configured");
  }

  let event;

  try {
    event = stripeClient().webhooks.constructEvent(
      req.body,
      req.headers["stripe-signature"],
      webhookSecret
    );
  } catch (error) {
    console.error("Stripe webhook signature error:", error.message);
    return res.status(400).send(`Webhook Error: ${error.message}`);
  }

  try {
    const stripe = stripeClient();

    const stripeObject = event.data.object;

    if (event.type === "charge.refunded") {
      const payment = await Payment.findOne({
        stripePaymentIntentId: stripeObject.payment_intent,
      });

      if (payment && payment.paymentStatus !== "Refunded") {
        payment.paymentStatus = "Refunded";
        payment.refundDetails = {
          refundedAmount: stripeObject.amount_refunded / 100,
          refundDate: new Date(),
          reason: "Stripe refund completed",
        };
        await payment.save();
      }

      return res.status(200).json({ received: true });
    }

    if (event.type !== "payment_intent.succeeded") {
      return res.status(200).json({ received: true });
    }

    const existingPayment = await Payment.findOne({
      stripePaymentIntentId: stripeObject.id,
    });

    if (existingPayment) {
      return res.status(200).json({ received: true });
    }

    const metadata = stripeObject.metadata ?? {};
    const dates = parseRentalDates(metadata.startDate, metadata.endDate);
    const renterId = metadata.renterId;
    const providerId = metadata.providerId;
    const carVariantId = metadata.carVariantId;
    const metadataRentalSubtotal = Number(metadata.rentalSubtotal);
    const metadataTotalAmount = Number(metadata.totalAmount);
    const usesBookingHold = metadata.bookingHoldId != null;
    const bookingHold = mongoose.isValidObjectId(metadata.bookingHoldId)
      ? await BookingHold.findById(metadata.bookingHoldId)
      : null;

    const holdMatchesPayment =
      !usesBookingHold ||
      (bookingHold &&
        bookingHold.renter.toString() === renterId &&
        bookingHold.provider.toString() === providerId &&
        bookingHold.carVariant.toString() === carVariantId &&
        bookingHold.paymentIntentId === stripeObject.id &&
        bookingHold.startDate.getTime() === dates.startDate?.getTime() &&
        bookingHold.endDate.getTime() === dates.endDate?.getTime() &&
        Math.round(bookingHold.totalAmount * 100) ===
          stripeObject.amount_received);

    const metadataIsValid =
      mongoose.isValidObjectId(renterId) &&
      mongoose.isValidObjectId(providerId) &&
      mongoose.isValidObjectId(carVariantId) &&
      !dates.error &&
      Number.isFinite(metadataRentalSubtotal) &&
      Number.isFinite(metadataTotalAmount) &&
      Math.round(metadataTotalAmount * 100) === stripeObject.amount_received &&
      holdMatchesPayment;

    if (!metadataIsValid) {
      console.error("Invalid booking metadata for", stripeObject.id);
      await refundUnavailablePayment(stripe, stripeObject);
      return res.status(200).json({ received: true });
    }

    // New PaymentIntents use the database snapshot in the hold. The metadata
    // fallback keeps already-created pre-deployment PaymentIntents compatible.
    const rentalSubtotal = bookingHold?.rentalSubtotal ?? metadataRentalSubtotal;
    const totalAmount = bookingHold?.totalAmount ?? metadataTotalAmount;

    const [renter, variant] = await Promise.all([
      Renter.findById(renterId).select("name username").lean(),
      CarVariant.findById(carVariantId).select(
        "isAvailable approvalStatus archivedAt provider car registrationNumber"
      ).populate("car", "brand model"),
    ]);

    if (
      !renter ||
      !variant ||
      !isPubliclyListed(variant) ||
      variant.provider.toString() !== providerId
    ) {
      await refundUnavailablePayment(stripe, stripeObject);
      return res.status(200).json({ received: true });
    }

    const paymentMethod = await detectPaymentMethod(stripe, stripeObject);
    const session = await mongoose.startSession();
    let bookingCreated = false;
    let failureCode = null;

    try {
      await session.withTransaction(async () => {
        // Updating the variant serializes simultaneous successful checkouts for
        // the same physical car. A retried transaction checks conflicts again.
        const variantLock = await CarVariant.updateOne(
          {
            _id: carVariantId,
            isAvailable: true,
            archivedAt: null,
            $or: [
              { approvalStatus: "Approved" },
              { approvalStatus: { $exists: false } },
            ],
          },
          { $inc: { reservationVersion: 1 } },
          { session }
        );

        if (variantLock.matchedCount !== 1) {
          const error = new Error("Vehicle is no longer listed");
          error.code = "VEHICLE_NOT_LISTED";
          throw error;
        }

        const duplicatePayment = await Payment.findOne({
          stripePaymentIntentId: stripeObject.id,
        }).session(session);

        if (duplicatePayment) {
          bookingCreated = true;
          return;
        }

        let currentHold = null;
        if (usesBookingHold) {
          currentHold = await BookingHold.findById(bookingHold._id).session(
            session
          );
          const paymentSucceededAt = new Date(event.created * 1000);

          if (
            !currentHold ||
            currentHold.status !== "Active" ||
            currentHold.paymentIntentId !== stripeObject.id
          ) {
            const error = new Error("Temporary reservation is no longer active");
            error.code = "HOLD_INVALID";
            throw error;
          }

          if (paymentSucceededAt > currentHold.expiresAt) {
            const error = new Error("Temporary reservation expired before payment");
            error.code = "HOLD_EXPIRED";
            throw error;
          }
        }

        const conflict = await Booking.exists(
          bookingConflictQuery(
            carVariantId,
            dates.startDate,
            dates.endDate
          )
        ).session(session);

        if (conflict) {
          const error = new Error("Selected dates are unavailable");
          error.code = "BOOKING_CONFLICT";
          throw error;
        }

        const [payment] = await Payment.create(
          [
            {
              renter: renterId,
              provider: providerId,
              amount: totalAmount,
              currency: "AED",
              paymentMethod,
              stripePaymentIntentId: stripeObject.id,
              paymentStatus: "Completed",
              paymentDate: new Date(),
            },
          ],
          { session }
        );

        const [booking] = await Booking.create(
          [
            {
              renter: renterId,
              carVariant: carVariantId,
              startDate: dates.startDate,
              endDate: dates.endDate,
              totalPrice: rentalSubtotal,
              status: "Confirmed",
              payment: payment._id,
            },
          ],
          { session }
        );

        const vehicleName = [variant.car?.brand, variant.car?.model]
          .filter(Boolean)
          .join(" ");
        await notifyBookingConfirmed({
          bookingId: booking._id,
          providerId: variant.provider,
          carVariantId,
          renterName: renter.name || renter.username,
          vehicleName: vehicleName || variant.registrationNumber || "vehicle",
          session,
        });

        if (currentHold) {
          currentHold.status = "Converted";
          currentHold.convertedBooking = booking._id;
          currentHold.purgeAt = new Date(
            Date.now() + BOOKING_HOLD_RETENTION_MS
          );
          await currentHold.save({ session });
        }

        bookingCreated = true;
      });
    } catch (error) {
      if (
        error.code !== "BOOKING_CONFLICT" &&
        error.code !== "VEHICLE_NOT_LISTED" &&
        error.code !== "HOLD_INVALID" &&
        error.code !== "HOLD_EXPIRED"
      ) {
        throw error;
      }
      failureCode = error.code;
    } finally {
      await session.endSession();
    }

    if (!bookingCreated) {
      if (usesBookingHold) {
        await releaseBookingHold(
          bookingHold?._id,
          failureCode === "HOLD_EXPIRED" ? "Expired" : "Cancelled"
        );
      }
      await refundUnavailablePayment(
        stripe,
        stripeObject,
        failureCode === "HOLD_EXPIRED"
          ? "refunded_hold_expired"
          : "refunded_unavailable"
      );
    } else {
      await stripe.paymentIntents.update(stripeObject.id, {
        metadata: { bookingOutcome: "confirmed" },
      });
    }

    return res.status(200).json({ received: true });
  } catch (error) {
    // A non-2xx response tells Stripe to retry a transient database or server
    // failure. Signature failures are handled separately above as 400 errors.
    console.error("Stripe webhook processing error:", error.message);
    return res.status(500).send("Webhook processing failed");
  }
};

export const refundPayment = async (req, res) => {
  try {
    const { paymentId } = req.params;
    const payment = await Payment.findById(paymentId);

    if (!payment) {
      return res.status(404).json({ message: "Payment not found" });
    }

    if (payment.paymentStatus !== "Completed") {
      return res.status(400).json({
        message: "Only a completed payment can be refunded",
      });
    }

    const booking = await Booking.findOne({ payment: paymentId });
    if (!booking || booking.status !== "Cancelled") {
      return res.status(400).json({
        message: "Cancel the booking before issuing its refund",
      });
    }

    if (!payment.stripePaymentIntentId) {
      return res.status(400).json({
        message: "Stripe payment reference is missing",
      });
    }

    const refund = await stripeClient().refunds.create(
      { payment_intent: payment.stripePaymentIntentId },
      { idempotencyKey: `diamondcar-refund-${payment._id}` }
    );

    payment.paymentStatus = "Refunded";
    payment.refundDetails = {
      stripeRefundId: refund.id,
      refundedAmount: refund.amount / 100,
      refundDate: new Date(),
      reason: "Booking cancelled",
    };
    await payment.save();

    return res.status(200).json({
      message: "Refund submitted successfully",
      payment,
    });
  } catch (error) {
    console.error("Stripe refund error:", error);
    return res.status(500).json({
      message: "Could not refund payment",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

const paymentMethodBelongsToCustomer = async (
  stripe,
  paymentMethodId,
  customerId
) => {
  const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);

  if (paymentMethod.customer !== customerId) {
    const error = new Error("Payment method does not belong to this renter");
    error.statusCode = 403;
    throw error;
  }

  return paymentMethod;
};

const paymentMethodErrorResponse = (res, error, fallback) => {
  console.error(`${fallback}:`, error);

  const statusCode =
    error.statusCode || (error?.code === "resource_missing" ? 404 : 500);

  return res.status(statusCode).json({
    message: statusCode < 500 ? error.message : fallback,
    ...(process.env.NODE_ENV !== "production" && {
      error: error.message,
    }),
  });
};

export const createCardSetupIntent = async (req, res) => {
  try {
    const { renterId } = req.body;
    const renter = await findRenter(renterId);
    const stripe = stripeClient();
    const customer = await getOrCreateStripeCustomer(stripe, renter);

    const [setupIntent, customerSession] = await Promise.all([
      stripe.setupIntents.create({
        customer: customer.id,
        payment_method_types: ["card"],
        usage: "on_session",
        metadata: { renterId: renter._id.toString() },
      }),
      createMobileCustomerSession(stripe, customer.id),
    ]);

    return res.status(201).json({
      setupIntentClientSecret: setupIntent.client_secret,
      customerId: customer.id,
      customerSessionClientSecret: customerSession.client_secret,
    });
  } catch (error) {
    return paymentMethodErrorResponse(
      res,
      error,
      "Could not start card setup"
    );
  }
};

export const getSavedPaymentMethods = async (req, res) => {
  try {
    const renter = await findRenter(req.params.renterId);

    if (!renter.stripeCustomerId) {
      return res.status(200).json({
        paymentMethods: [],
        defaultPaymentMethodId: null,
      });
    }

    const stripe = stripeClient();
    let customer;

    try {
      customer = await stripe.customers.retrieve(renter.stripeCustomerId);
    } catch (error) {
      if (error?.code !== "resource_missing") throw error;

      renter.stripeCustomerId = null;
      await renter.save();
      return res.status(200).json({
        paymentMethods: [],
        defaultPaymentMethodId: null,
      });
    }

    if (customer.deleted) {
      renter.stripeCustomerId = null;
      await renter.save();
      return res.status(200).json({
        paymentMethods: [],
        defaultPaymentMethodId: null,
      });
    }

    const methods = await stripe.paymentMethods.list({
      customer: customer.id,
      type: "card",
      limit: 100,
    });

    const defaultPaymentMethod =
      customer.invoice_settings?.default_payment_method;
    const defaultPaymentMethodId =
      typeof defaultPaymentMethod === "string"
        ? defaultPaymentMethod
        : defaultPaymentMethod?.id ?? null;

    return res.status(200).json({
      defaultPaymentMethodId,
      paymentMethods: methods.data.map((method) => ({
        id: method.id,
        brand: method.card?.brand ?? "card",
        last4: method.card?.last4 ?? "",
        expMonth: method.card?.exp_month ?? null,
        expYear: method.card?.exp_year ?? null,
        funding: method.card?.funding ?? null,
        country: method.card?.country ?? null,
        isDefault: method.id === defaultPaymentMethodId,
      })),
    });
  } catch (error) {
    return paymentMethodErrorResponse(
      res,
      error,
      "Could not load payment methods"
    );
  }
};

export const setDefaultPaymentMethod = async (req, res) => {
  try {
    const { renterId, paymentMethodId } = req.body;

    if (!paymentMethodId) {
      return res.status(400).json({
        message: "Payment method ID is required",
      });
    }

    const renter = await findRenter(renterId);
    if (!renter.stripeCustomerId) {
      return res.status(404).json({ message: "Stripe customer not found" });
    }

    const stripe = stripeClient();
    await paymentMethodBelongsToCustomer(
      stripe,
      paymentMethodId,
      renter.stripeCustomerId
    );

    await stripe.customers.update(renter.stripeCustomerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });

    return res.status(200).json({
      message: "Default payment method updated",
      defaultPaymentMethodId: paymentMethodId,
    });
  } catch (error) {
    return paymentMethodErrorResponse(
      res,
      error,
      "Could not update the default payment method"
    );
  }
};

export const removeSavedPaymentMethod = async (req, res) => {
  try {
    const { renterId, paymentMethodId } = req.params;
    const renter = await findRenter(renterId);

    if (!renter.stripeCustomerId) {
      return res.status(404).json({ message: "Stripe customer not found" });
    }

    const stripe = stripeClient();
    await paymentMethodBelongsToCustomer(
      stripe,
      paymentMethodId,
      renter.stripeCustomerId
    );

    const customer = await stripe.customers.retrieve(renter.stripeCustomerId);
    const defaultPaymentMethod = customer.deleted
      ? null
      : customer.invoice_settings?.default_payment_method;
    const defaultPaymentMethodId =
      typeof defaultPaymentMethod === "string"
        ? defaultPaymentMethod
        : defaultPaymentMethod?.id;

    if (defaultPaymentMethodId === paymentMethodId) {
      await stripe.customers.update(renter.stripeCustomerId, {
        invoice_settings: { default_payment_method: null },
      });
    }

    await stripe.paymentMethods.detach(paymentMethodId);

    return res.status(200).json({ message: "Payment method removed" });
  } catch (error) {
    return paymentMethodErrorResponse(
      res,
      error,
      "Could not remove the payment method"
    );
  }
};

const roundedMoney = (value) => Math.round((Number(value) || 0) * 100) / 100;

const parseEarningsRange = (fromValue, toValue) => {
  const now = new Date();
  const defaultFrom = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    1
  ));
  const from = fromValue ? new Date(fromValue) : defaultFrom;
  const to = toValue ? new Date(toValue) : now;

  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
    return { error: "from and to must be valid ISO dates" };
  }
  if (from > to) {
    return { error: "from must be before to" };
  }
  if (to - from > 366 * 86_400_000) {
    return { error: "Earnings range cannot exceed 366 days" };
  }

  return { from, to };
};

const chartBucket = (date, groupByMonth) => {
  const value = new Date(date);
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, "0");
  if (groupByMonth) return `${year}-${month}`;
  const day = String(value.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const bookingSummary = (booking) => {
  const car = booking?.carVariant?.car;
  const brand = car?.brand?.trim() ?? "";
  const model = car?.model?.trim() ?? "";
  return {
    bookingId: booking?._id ?? null,
    carVariantId: booking?.carVariant?._id ?? null,
    vehicle: `${brand} ${model}`.trim() || "Vehicle",
    registrationNumber: booking?.carVariant?.registrationNumber ?? "",
  };
};

// Provider-facing accounting summary. This reads only persisted payments
// created by the verified Stripe webhook; Flutter never calculates earnings.
export const getProviderEarnings = async (req, res) => {
  try {
    const { providerId } = req.params;
    if (!mongoose.isValidObjectId(providerId)) {
      return res.status(400).json({ message: "Invalid provider ID" });
    }

    const range = parseEarningsRange(req.query.from, req.query.to);
    if (range.error) {
      return res.status(400).json({ message: range.error });
    }

    const requestedLimit = Number.parseInt(req.query.limit, 10);
    const transactionLimit = Number.isFinite(requestedLimit)
      ? Math.min(100, Math.max(1, requestedLimit))
      : 30;
    const dateRange = { $gte: range.from, $lte: range.to };

    const [receivedPayments, refundedPayments] = await Promise.all([
      Payment.find({
        provider: providerId,
        paymentStatus: { $in: ["Completed", "Refunded"] },
        paymentDate: dateRange,
      })
        .populate("renter", "name username")
        .lean(),
      Payment.find({
        provider: providerId,
        paymentStatus: "Refunded",
        "refundDetails.refundDate": dateRange,
      })
        .populate("renter", "name username")
        .lean(),
    ]);

    const paymentIds = [
      ...new Set(
        [...receivedPayments, ...refundedPayments].map((payment) =>
          payment._id.toString()
        )
      ),
    ];

    const bookings = paymentIds.length
      ? await Booking.find({ payment: { $in: paymentIds } })
          .select("payment totalPrice status carVariant")
          .populate({
            path: "carVariant",
            select: "car registrationNumber",
            populate: {
              path: "car",
              select: "brand model year category",
            },
          })
          .lean()
      : [];
    const bookingsByPayment = new Map(
      bookings.map((booking) => [booking.payment.toString(), booking])
    );

    let rentalRevenue = 0;
    let depositsCollected = 0;
    let grossCollected = 0;
    let refunds = 0;

    for (const payment of receivedPayments) {
      const booking = bookingsByPayment.get(payment._id.toString());
      const rentalAmount = Math.min(
        Number(payment.amount) || 0,
        Number(booking?.totalPrice ?? payment.amount) || 0
      );
      rentalRevenue += rentalAmount;
      grossCollected += Number(payment.amount) || 0;
      depositsCollected += Math.max(
        0,
        (Number(payment.amount) || 0) - rentalAmount
      );
    }

    for (const payment of refundedPayments) {
      refunds += Number(payment.refundDetails?.refundedAmount) || 0;
    }

    const groupByMonth = range.to - range.from > 45 * 86_400_000;
    const chart = new Map();
    const addChartValue = (date, field, amount) => {
      const key = chartBucket(date, groupByMonth);
      const point = chart.get(key) ?? {
        period: key,
        collected: 0,
        refunds: 0,
        net: 0,
      };
      point[field] += amount;
      point.net += field === "refunds" ? -amount : amount;
      chart.set(key, point);
    };

    receivedPayments.forEach((payment) =>
      addChartValue(payment.paymentDate, "collected", Number(payment.amount) || 0)
    );
    refundedPayments.forEach((payment) =>
      addChartValue(
        payment.refundDetails.refundDate,
        "refunds",
        Number(payment.refundDetails.refundedAmount) || 0
      )
    );

    const events = [];
    for (const payment of receivedPayments) {
      const booking = bookingsByPayment.get(payment._id.toString());
      events.push({
        id: `${payment._id}:payment`,
        type: "Payment",
        date: payment.paymentDate,
        amount: roundedMoney(payment.amount),
        paymentMethod: payment.paymentMethod,
        renterName:
          payment.renter?.name ?? payment.renter?.username ?? "Renter",
        reference: payment.transactionId,
        ...bookingSummary(booking),
      });
    }
    for (const payment of refundedPayments) {
      const booking = bookingsByPayment.get(payment._id.toString());
      events.push({
        id: `${payment._id}:refund`,
        type: "Refund",
        date: payment.refundDetails.refundDate,
        amount: -roundedMoney(payment.refundDetails.refundedAmount),
        paymentMethod: payment.paymentMethod,
        renterName:
          payment.renter?.name ?? payment.renter?.username ?? "Renter",
        reference: payment.refundDetails.stripeRefundId ?? payment.transactionId,
        reason: payment.refundDetails.reason ?? "Refund",
        ...bookingSummary(booking),
      });
    }
    events.sort((left, right) => new Date(right.date) - new Date(left.date));

    const currencies = new Set(
      [...receivedPayments, ...refundedPayments].map(
        (payment) => payment.currency
      )
    );
    const currency = currencies.size === 1 ? [...currencies][0] : "AED";

    return res.status(200).json({
      providerId,
      currency,
      range: {
        from: range.from,
        to: range.to,
        groupBy: groupByMonth ? "month" : "day",
      },
      summary: {
        rentalRevenue: roundedMoney(rentalRevenue),
        depositsCollected: roundedMoney(depositsCollected),
        grossCollected: roundedMoney(grossCollected),
        refunds: roundedMoney(refunds),
        netEarnings: roundedMoney(grossCollected - refunds),
        paymentCount: receivedPayments.length,
        refundCount: refundedPayments.length,
      },
      chart: [...chart.values()]
        .sort((left, right) => left.period.localeCompare(right.period))
        .map((point) => ({
          ...point,
          collected: roundedMoney(point.collected),
          refunds: roundedMoney(point.refunds),
          net: roundedMoney(point.net),
        })),
      transactions: events.slice(0, transactionLimit),
    });
  } catch (error) {
    console.error("Get provider earnings error:", error);
    return res.status(500).json({
      message: "Could not load provider earnings",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};
