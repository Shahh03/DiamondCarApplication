import mongoose from "mongoose";

import Booking from "../models/booking.js";
import CarVariant from "../models/carVariant.js";
import Provider from "../models/provider.js";

const forbidden = (res) =>
  res.status(403).json({ message: "You are not authorized to perform this action" });

const hiddenResource = (res) =>
  res.status(404).json({ message: "Resource not found" });

export const requireRole = (...allowedTypes) => {
  const allowed = new Set(allowedTypes);
  return (req, res, next) => {
    if (!req.auth || !allowed.has(req.auth.type)) return forbidden(res);
    return next();
  };
};

export const requireParamOwner = ({
  parameter = "renterId",
  type = "Renter",
  allowAdmin = false,
} = {}) =>
  (req, res, next) => {
    if (allowAdmin && req.auth?.type === "Admin") return next();
    if (
      req.auth?.type !== type ||
      req.auth.userId !== req.params[parameter]
    ) {
      return forbidden(res);
    }
    return next();
  };

export const requireBodyOwner = ({
  field = "renterId",
  type = "Renter",
  allowAdmin = false,
} = {}) =>
  (req, res, next) => {
    if (allowAdmin && req.auth?.type === "Admin") return next();
    if (
      req.auth?.type !== type ||
      req.auth.userId !== req.body?.[field]?.toString()
    ) {
      return forbidden(res);
    }
    return next();
  };

export const requireSelfOrAdmin = (parameter = "userId") =>
  requireParamOwner({ parameter, type: "Renter", allowAdmin: true });

export const requireAccountSelfOrAdmin = (parameter = "userId") =>
  (req, res, next) => {
    if (req.auth?.type === "Admin") return next();
    if (req.auth?.userId !== req.params[parameter]) return forbidden(res);
    return next();
  };

export const restrictPublicSignup = (req, res, next) => {
  if (!new Set(["Renter", "Provider"]).has(req.body?.type)) {
    return res.status(400).json({
      message: "Public signup only supports Renter or Provider accounts",
    });
  }

  // These values are owned by the server and must never be accepted from a
  // public signup request, even though discriminator schemas contain them.
  for (const field of [
    "isVerified",
    "status",
    "stripeCustomerId",
    "refreshTokens",
    "wishlist",
    "complaints",
    "profilePicture",
    "profilePicturePublicId",
    "imagePublicIds",
  ]) {
    delete req.body[field];
  }

  return next();
};

export const requireAcceptedProvider = async (req, res, next) => {
  try {
    if (req.auth?.type === "Admin") return next();
    if (req.auth?.type !== "Provider") return forbidden(res);

    const provider = await Provider.findById(req.auth.userId).select(
      "status isVerified"
    );
    if (!provider || provider.status !== "Accepted") {
      return res.status(403).json({
        message: "Provider account has not been accepted",
      });
    }
    return next();
  } catch (error) {
    return next(error);
  }
};

export const requireBookingAccess = ({ renterOnly = false } = {}) =>
  async (req, res, next) => {
    try {
      const { bookingId } = req.params;
      if (!mongoose.isValidObjectId(bookingId)) return hiddenResource(res);
      if (req.auth?.type === "Admin") return next();

      const booking = await Booking.findById(bookingId)
        .select("renter carVariant")
        .populate({ path: "carVariant", select: "provider" });
      if (!booking) return hiddenResource(res);

      const renterOwnsBooking =
        req.auth?.type === "Renter" &&
        booking.renter.toString() === req.auth.userId;
      const providerOwnsVariant =
        !renterOnly &&
        req.auth?.type === "Provider" &&
        booking.carVariant?.provider?.toString() === req.auth.userId;

      if (!renterOwnsBooking && !providerOwnsVariant) {
        return hiddenResource(res);
      }

      req.authorizedBooking = booking;
      return next();
    } catch (error) {
      return next(error);
    }
  };

export const requireCarVariantProvider = async (req, res, next) => {
  try {
    if (req.auth?.type === "Admin") return next();
    if (req.auth?.type !== "Provider") return forbidden(res);

    const { carVariantId } = req.params;
    if (!mongoose.isValidObjectId(carVariantId)) return hiddenResource(res);

    const variant = await CarVariant.findById(carVariantId).select("provider");
    if (!variant || variant.provider.toString() !== req.auth.userId) {
      return hiddenResource(res);
    }

    req.authorizedCarVariant = variant;
    return next();
  } catch (error) {
    return next(error);
  }
};
