import express from "express";

import {
  cancelBooking,
  checkBookingAvailability,
  getbookingbyId,
  getUnavailableDates,
  getProviderBookings,
} from "../controllers/booking/booking.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import { requireBookingAccess ,  requireParamOwner } from "../middlewares/authorization.js";

const router = express.Router();

// These two endpoints expose only calendar availability and remain public.
router.get("/booking/unavailable-dates/:carVariantId", getUnavailableDates);
router.get("/booking/availability/:carVariantId", checkBookingAvailability);

router.get(
  "/booking/get/:bookingId",
  authenticateAccessToken,
  requireBookingAccess(),
  getbookingbyId
);
router.put(
  "/booking/cancel/:bookingId",
  authenticateAccessToken,
  requireBookingAccess({ renterOnly: true }),
  cancelBooking
);
router.get(
  "/booking/getbookingForProvider/:providerId",
  authenticateAccessToken,
  requireParamOwner({
    parameter: "providerId",
    type: "Provider",
    allowAdmin: true,
  }),
  getProviderBookings
);

export default router;
