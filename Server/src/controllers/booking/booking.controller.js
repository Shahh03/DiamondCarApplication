import Stripe from "stripe";

import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";

const stripeClient = () => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error("STRIPE_SECRET_KEY is not configured");
  }

  return new Stripe(process.env.STRIPE_SECRET_KEY);
};

const parseRentalDates = (startValue, endValue) => {
  const startDate = new Date(startValue);
  const endDate = new Date(endValue);

  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
    return { error: "Start date and end date must be valid dates" };
  }

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  if (startDate < today) {
    return { error: "Pickup date cannot be in the past" };
  }

  if (endDate <= startDate) {
    return { error: "Return date must be after pickup date" };
  }

  return { startDate, endDate };
};

// Date-only rentals use inclusive boundaries. A car returned on a given date
// cannot be picked up by another renter until the following day.
const confirmedConflictQuery = (carVariantId, startDate, endDate) => ({
  carVariant: carVariantId,
  status: "Confirmed",
  startDate: { $lte: endDate },
  endDate: { $gte: startDate },
});

export const checkBookingAvailability = async (req, res) => {
  try {
    const { carVariantId } = req.params;
    const { startDate: startValue, endDate: endValue } = req.query;

    if (!startValue || !endValue) {
      return res.status(400).json({
        available: false,
        message: "Start date and end date are required",
      });
    }

    const dates = parseRentalDates(startValue, endValue);
    if (dates.error) {
      return res.status(400).json({
        available: false,
        message: dates.error,
      });
    }

    const variant = await CarVariant.findById(carVariantId).select(
      "isAvailable"
    );

    if (!variant) {
      return res.status(404).json({
        available: false,
        message: "Car variant not found",
      });
    }

    if (!variant.isAvailable) {
      return res.status(200).json({
        available: false,
        message: "This car is currently unavailable",
      });
    }

    const conflict = await Booking.exists(
      confirmedConflictQuery(
        carVariantId,
        dates.startDate,
        dates.endDate
      )
    );

    return res.status(200).json({
      available: !conflict,
      message: conflict
        ? "This car is already booked for those dates"
        : "Available for your selected dates",
    });
  } catch (error) {
    return res.status(500).json({
      available: false,
      message: "Could not check availability",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

export const getUnavailableDates = async (req, res) => {
  try {
    const { carVariantId } = req.params;

    const variant = await CarVariant.exists({ _id: carVariantId });
    if (!variant) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    const bookings = await Booking.find({
      carVariant: carVariantId,
      status: "Confirmed",
      endDate: { $gte: today },
    })
      .select("startDate endDate -_id")
      .sort({ startDate: 1 })
      .lean();

    return res.status(200).json({
      unavailableRanges: bookings.map((booking) => ({
        startDate: booking.startDate,
        endDate: booking.endDate,
      })),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Could not load unavailable dates",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

export const cancelBooking = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = await Booking.findById(bookingId).populate("payment");

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.status === "Cancelled") {
      return res.status(400).json({ message: "Booking is already cancelled" });
    }

    if (booking.status === "Completed" || booking.endDate < new Date()) {
      return res.status(400).json({
        message: "Cannot cancel a booking that has already ended",
      });
    }

    if (booking.startDate < new Date()) {
      return res.status(400).json({
        message: "Cannot cancel a booking that has already started",
      });
    }

    const payment = booking.payment;

    if (
      payment?.paymentStatus === "Completed" &&
      payment.stripePaymentIntentId
    ) {
      const stripe = stripeClient();
      const refund = await stripe.refunds.create(
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
    }

    booking.status = "Cancelled";
    await booking.save();

    return res.status(200).json({
      message:
        payment?.paymentStatus === "Refunded"
          ? "Booking cancelled and refund submitted"
          : "Booking cancelled successfully",
    });
  } catch (error) {
    console.error("Cancel booking error:", error);
    return res.status(500).json({
      message: "Could not cancel booking",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

export const getbookingbyId = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = await Booking.findById(bookingId)
      .populate({
        path: "carVariant",
        populate: [{ path: "car" }, { path: "provider" }],
      })
      .populate("renter")
      .populate("payment");

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    return res.status(200).json(booking);
  } catch (error) {
    return res.status(500).json({
      message: "Internal Server Error",
      ...(process.env.NODE_ENV !== "production" && {
        error: error.message,
      }),
    });
  }
};

export { confirmedConflictQuery };
