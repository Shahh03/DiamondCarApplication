import mongoose from "mongoose";
import { v4 as uuidv4 } from "uuid";

const paymentSchema = new mongoose.Schema(
  {
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
      min: 0,
    },
    currency: {
      type: String,
      enum: ["AED"],
      default: "AED",
    },
    paymentMethod: {
      type: String,
      enum: ["Card", "Apple Pay", "Google Pay", "Link"],
      default: "Card",
    },
    transactionId: {
      type: String,
      unique: true,
      default: uuidv4,
    },
    stripePaymentIntentId: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ["Completed", "Failed", "Refunded"],
      default: "Completed",
    },
    paymentDate: {
      type: Date,
      default: Date.now,
    },
    refundDetails: {
      stripeRefundId: { type: String },
      refundedAmount: { type: Number },
      refundDate: { type: Date },
      reason: { type: String },
    },
  },
  { timestamps: true }
);

const Payment = mongoose.model("Payment", paymentSchema);

export default Payment;
