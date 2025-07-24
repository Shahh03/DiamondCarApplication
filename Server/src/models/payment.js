import mongoose from "mongoose";
import { v4 as uuidv4 } from "uuid";

const paymentSchema = new mongoose.Schema({
  renter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Renter",
    required: true,
  },
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Provider",
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  currency: {
    type: String,
    enum: ["USD", "CAD", "GBP", "EUR", "AUD", "EGP" , "AED", "SAR", "QAR", "OMR", "BHD"],
    default: "AED",
  },
  paymentMethod: {
    type: String,
    enum: ["Credit Card", "Debit Card", "PayPal", "Bank Transfer"],
    required: true,
  },
  transactionId: { 
    type: String, 
    unique: true, 
    default: uuidv4 
  }, // Auto-generate unique ID
  paymentStatus: {
    type: String,
    enum: ["Completed", "Failed", "Refunded"],
    default: "Completed"
  },
  paymentDate: {
    type: Date,
    default: Date.now,
  },
  refundDetails: {
    refundedAmount: { type: Number },
    refundDate: { type: Date },
    reason: { type: String },
  },
});


const Payment = mongoose.model("Payment", paymentSchema);

export default Payment;
