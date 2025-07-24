import express from "express";
import {createPaymentAndBooking ,refundPayment} from "../controllers/payment/payment.controller.js";


const router = express.Router();

router.post("/paymentAndBooking/create", createPaymentAndBooking); //works

router.put("/payment/refund/:paymentId", refundPayment); //works



export default router;
