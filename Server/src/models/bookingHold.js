import mongoose from "mongoose";

const bookingHoldSchema = new mongoose.Schema(
  {
    renter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Renter",
      required: true,
      index: true,
    },
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Provider",
      required: true,
      index: true,
    },
    carVariant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "CarVariant",
      required: true,
      index: true,
    },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    days: { type: Number, required: true, min: 1 },
    dailyRate: { type: Number, required: true, min: 0 },
    rentalSubtotal: { type: Number, required: true, min: 0 },
    depositAmount: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
    currency: {
      type: String,
      enum: ["AED"],
      default: "AED",
      required: true,
    },
    status: {
      type: String,
      enum: ["Active", "Expiring", "Converted", "Cancelled", "Expired"],
      default: "Active",
      required: true,
      index: true,
    },
    checkoutReference: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    paymentIntentId: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: true,
    },
    convertedBooking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Booking",
      default: null,
    },
    expiryClaimedAt: {
      type: Date,
      default: null,
    },
    lastExpiryError: {
      type: String,
      default: "",
      maxlength: 500,
    },
    // Keep the hold long enough to safely handle delayed Stripe webhooks.
    // MongoDB removes it later; expiresAt alone controls availability.
    purgeAt: {
      type: Date,
      required: true,
    },
  },
  { timestamps: true }
);

bookingHoldSchema.index({ purgeAt: 1 }, { expireAfterSeconds: 0 });
bookingHoldSchema.index({
  carVariant: 1,
  status: 1,
  expiresAt: 1,
  startDate: 1,
  endDate: 1,
});

const BookingHold = mongoose.model("BookingHold", bookingHoldSchema);

export default BookingHold;
