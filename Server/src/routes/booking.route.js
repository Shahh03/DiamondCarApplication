import express from "express";
import  { cancelBooking , getbookingbyId} from "../controllers/booking/booking.controller.js";
import { get } from "mongoose";

const router = express.Router();

router.put("/booking/cancel/:bookingId", cancelBooking); //works

router.get("/booking/get/:bookingId", getbookingbyId);

export default router;
