
import mongoose from "mongoose";
import Stripe from "stripe";

import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";

export const getProviderBookings = async (req, res) => {
  try {
    const { providerId } = req.params;
    if (!mongoose.isValidObjectId(providerId)) {
      return res.status(400).json({ message: "Invalid provider ID" });
    }

    const variantIds = await CarVariant.find({ provider: providerId })
      .select("_id")
      .lean();

    const bookings = await Booking.find({
      carVariant: { $in: variantIds.map((variant) => variant._id) },
    })
      .populate(
        "renter",
        "name username email phoneNumber profilePicture nationality birthDate " +
          "occupation gender isVerified drivingLicenseNumber idCardNumber " +
          "location currency"
      )
      .populate({
        path: "carVariant",
        select:
          "car color registrationNumber rentalPricePerDay " +
          "depositAmount isAvailable images",
        populate: { path: "car" },
      })
      .populate(
        "payment",
        "amount currency paymentMethod paymentStatus paymentDate refundDetails"
      )
      .sort({ startDate: 1, createdAt: -1 })
      .lean();

    return res.status(200).json(bookings);
  } catch (error) {
    console.error("Get provider bookings error:", error);
    return res.status(500).json({ message: "Could not load provider bookings" });
  }
};

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
  if (startDate < today) return { error: "Pickup date cannot be in the past" };
  if (endDate <= startDate) {
    return { error: "Return date must be after pickup date" };
  }
  return { startDate, endDate };
};

export const confirmedConflictQuery = (carVariantId, startDate, endDate) => ({
  carVariant: carVariantId,
  status: { $in: ["Confirmed", "InProgress"] },
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
      return res.status(400).json({ available: false, message: dates.error });
    }

    const variant = await CarVariant.findById(carVariantId).select(
      "isAvailable approvalStatus archivedAt"
    );
    if (!variant) {
      return res.status(404).json({ available: false, message: "Car variant not found" });
    }
    if (
      !variant.isAvailable ||
      variant.approvalStatus !== "Approved" ||
      variant.archivedAt
    ) {
      return res.status(200).json({
        available: false,
        message: "This vehicle is not currently listed for renters",
      });
    }

    const conflict = await Booking.exists(
      confirmedConflictQuery(carVariantId, dates.startDate, dates.endDate)
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
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const getUnavailableDates = async (req, res) => {
  try {
    const { carVariantId } = req.params;
    if (!(await CarVariant.exists({ _id: carVariantId }))) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const bookings = await Booking.find({
      carVariant: carVariantId,
      status: { $in: ["Confirmed", "InProgress"] },
      endDate: { $gte: today },
    })
      .select("startDate endDate -_id")
      .sort({ startDate: 1 })
      .lean();

    return res.status(200).json({
      unavailableRanges: bookings.map(({ startDate, endDate }) => ({
        startDate,
        endDate,
      })),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Could not load unavailable dates",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.bookingId).populate("payment");
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.status === "Cancelled") {
      return res.status(400).json({ message: "Booking is already cancelled" });
    }
    if (booking.status === "InProgress") {
      return res.status(400).json({
        message: "Cannot cancel a rental that is already in progress",
      });
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
    if (payment?.paymentStatus === "Completed" && payment.stripePaymentIntentId) {
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
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const startBooking = async (req, res) => {
  try {
    const currentBooking = await Booking.findById(req.params.bookingId).select(
      "status carVariant"
    );

    if (!currentBooking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const messageByStatus = {
      InProgress: "This rental is already in progress",
      Completed: "A completed rental cannot be started",
      Cancelled: "A cancelled booking cannot be started",
    };

    if (currentBooking.status !== "Confirmed") {
      return res.status(409).json({
        message:
          messageByStatus[currentBooking.status] ??
          "This booking cannot be started",
      });
    }

    const vehicleIsOnRent = await Booking.exists({
      _id: { $ne: currentBooking._id },
      carVariant: currentBooking.carVariant,
      status: "InProgress",
    });

    if (vehicleIsOnRent) {
      return res.status(409).json({
        message:
          "This vehicle is already on rent. Complete its active rental " +
          "before starting this booking.",
      });
    }

    const booking = await Booking.findOneAndUpdate(
      {
        _id: req.params.bookingId,
        status: "Confirmed",
      },
      {
        $set: {
          status: "InProgress",
          startedAt: new Date(),
          completedAt: null,
        },
      },
      { new: true, runValidators: true }
    ).select("status startDate endDate startedAt completedAt");

    if (booking) {
      return res.status(200).json({
        message: "Rental started successfully",
        booking,
      });
    }

    const latestBooking = await Booking.findById(req.params.bookingId).select(
      "status"
    );

    return res.status(409).json({
      message:
        messageByStatus[latestBooking?.status] ??
        "This booking could not be started because its status changed. Refresh and try again.",
    });
  } catch (error) {
    console.error("Start booking error:", error);
    return res.status(500).json({
      message: "Could not start rental",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const completeBooking = async (req, res) => {
  try {
    const booking = await Booking.findOneAndUpdate(
      {
        _id: req.params.bookingId,
        status: "InProgress",
      },
      {
        $set: {
          status: "Completed",
          completedAt: new Date(),
        },
      },
      { new: true, runValidators: true }
    ).select("status startDate endDate startedAt completedAt");

    if (booking) {
      return res.status(200).json({
        message: "Rental completed successfully",
        booking,
      });
    }

    const currentBooking = await Booking.findById(req.params.bookingId).select(
      "status"
    );
    if (!currentBooking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const messageByStatus = {
      Confirmed: "Start the rental before marking it as completed",
      Completed: "Rental is already completed",
      Cancelled: "A cancelled booking cannot be completed",
    };

    return res.status(409).json({
      message:
        messageByStatus[currentBooking.status] ??
        "Booking cannot be marked as completed",
    });
  } catch (error) {
    console.error("Complete booking error:", error);
    return res.status(500).json({
      message: "Could not complete rental",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const getbookingbyId = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.bookingId)
      .populate({
        path: "carVariant",
        select: "provider car color rentalPricePerDay depositAmount images",
        populate: [
          { path: "car" },
          {
            path: "provider",
            select:
              "companyName contactPerson.name contactPerson.phoneNumber " +
              "contactPerson.email address profilePicture isVerified status",
          },
        ],
      })
      .populate("renter", "name phoneNumber profilePicture")
      .populate(
        "payment",
        "amount currency paymentMethod paymentStatus paymentDate refundDetails"
      );

    if (!booking) return res.status(404).json({ message: "Booking not found" });
    return res.status(200).json(booking);
  } catch (error) {
    return res.status(500).json({
      message: "Internal Server Error",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

