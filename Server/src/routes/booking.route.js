import express from "express";

import {
  cancelBooking,
  checkBookingAvailability,
  getbookingbyId,
  getUnavailableDates,
} from "../controllers/booking/booking.controller.js";

const router = express.Router();

router.get(
  "/booking/unavailable-dates/:carVariantId",
  getUnavailableDates
);
router.get("/booking/availability/:carVariantId", checkBookingAvailability);
router.get("/booking/get/:bookingId", getbookingbyId);
router.put("/booking/cancel/:bookingId", cancelBooking);

export default router;
