import mongoose from "mongoose";

import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";
import Payment from "../../models/payment.js";
import Provider from "../../models/provider.js";

const money = (value) => Math.round((Number(value) || 0) * 100) / 100;

const publicBooking = (booking) => {
  if (!booking) return null;
  const variant = booking.carVariant;
  const car = variant?.car;
  const renter = booking.renter;

  return {
    id: booking._id,
    status: booking.status,
    startDate: booking.startDate,
    endDate: booking.endDate,
    totalPrice: booking.totalPrice,
    renter: {
      id: renter?._id ?? null,
      name: renter?.name ?? "Renter",
      profilePicture: renter?.profilePicture ?? "",
    },
    vehicle: {
      carVariantId: variant?._id ?? null,
      name: `${car?.brand ?? ""} ${car?.model ?? ""}`.trim() || "Vehicle",
      registrationNumber: variant?.registrationNumber ?? "",
      image: variant?.images?.[0] ?? "",
    },
  };
};

const populateDashboardBooking = (query) =>
  query
    .populate("renter", "name profilePicture")
    .populate({
      path: "carVariant",
      select: "car registrationNumber images",
      populate: { path: "car", select: "brand model year category" },
    })
    .lean();

export const getAllProviders = async (_req, res) => {
  try {
    const providers = await Provider.find();
    return res.status(200).json(providers);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

export const getProviderbyId = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.providerId)) {
      return res.status(400).json({ message: "Invalid provider ID" });
    }

    const provider = await Provider.findById(req.params.providerId);
    if (!provider) {
      return res.status(404).json({ message: "Provider not found" });
    }
    return res.status(200).json(provider);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

export const getProviderDashboard = async (req, res) => {
  try {
    const { providerId } = req.params;
    if (!mongoose.isValidObjectId(providerId)) {
      return res.status(400).json({ message: "Invalid provider ID" });
    }

    const providerExists = await Provider.exists({ _id: providerId });
    if (!providerExists) {
      return res.status(404).json({ message: "Provider not found" });
    }

    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date(now);
    todayEnd.setUTCHours(23, 59, 59, 999);
    const monthStart = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      1
    ));

    const variants = await CarVariant.find({ provider: providerId })
      .select("_id isAvailable")
      .lean();
    const variantIds = variants.map((variant) => variant._id);
    const bookingOwnerQuery = { carVariant: { $in: variantIds } };

    const [
      activeBookings,
      upcomingBookings,
      completedBookings,
      cancelledBookings,
      nextRental,
      recentBookings,
      collectedResult,
      refundedResult,
    ] = await Promise.all([
      Booking.countDocuments({
        ...bookingOwnerQuery,
        status: "InProgress",
      }),
      Booking.countDocuments({
        ...bookingOwnerQuery,
        status: "Confirmed",
        startDate: { $gte: todayStart },
      }),
      Booking.countDocuments({ ...bookingOwnerQuery, status: "Completed" }),
      Booking.countDocuments({ ...bookingOwnerQuery, status: "Cancelled" }),
      populateDashboardBooking(
        Booking.findOne({
          ...bookingOwnerQuery,
          status: "Confirmed",
          startDate: { $gte: todayStart },
        }).sort({ startDate: 1 })
      ),
      populateDashboardBooking(
        Booking.find(bookingOwnerQuery).sort({ createdAt: -1 }).limit(5)
      ),
      Payment.aggregate([
        {
          $match: {
            provider: new mongoose.Types.ObjectId(providerId),
            paymentStatus: { $in: ["Completed", "Refunded"] },
            paymentDate: { $gte: monthStart, $lte: now },
          },
        },
        { $group: { _id: null, amount: { $sum: "$amount" }, count: { $sum: 1 } } },
      ]),
      Payment.aggregate([
        {
          $match: {
            provider: new mongoose.Types.ObjectId(providerId),
            paymentStatus: "Refunded",
            "refundDetails.refundDate": { $gte: monthStart, $lte: now },
          },
        },
        {
          $group: {
            _id: null,
            amount: { $sum: "$refundDetails.refundedAmount" },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const totalCars = variants.length;
    const availableCars = variants.filter(
      (variant) => variant.isAvailable === true
    ).length;
    const monthCollected = collectedResult[0]?.amount ?? 0;
    const monthRefunds = refundedResult[0]?.amount ?? 0;

    return res.status(200).json({
      providerId,
      currency: "AED",
      generatedAt: now,
      fleet: {
        total: totalCars,
        available: availableCars,
        unavailable: totalCars - availableCars,
        availabilityRate:
          totalCars === 0 ? 0 : Math.round((availableCars / totalCars) * 100),
      },
      bookings: {
        active: activeBookings,
        upcoming: upcomingBookings,
        completed: completedBookings,
        cancelled: cancelledBookings,
      },
      earnings: {
        monthCollected: money(monthCollected),
        monthRefunds: money(monthRefunds),
        monthNet: money(monthCollected - monthRefunds),
        paymentCount: collectedResult[0]?.count ?? 0,
        refundCount: refundedResult[0]?.count ?? 0,
      },
      nextRental: publicBooking(nextRental),
      recentBookings: recentBookings.map(publicBooking),
    });
  } catch (error) {
    console.error("Get provider dashboard error:", error);
    return res.status(500).json({
      message: "Could not load provider dashboard",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};
