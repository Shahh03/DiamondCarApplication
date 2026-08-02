import mongoose from "mongoose";

const bookingSchema = new mongoose.Schema(
  {
    renter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Renter",
      required: true,
    },
    carVariant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "CarVariant",
      required: true,
    },
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    totalPrice: {
      type: Number,
      required: true,
      min: 0,
    },
    status: {
      type: String,
      enum: ["Confirmed", "Cancelled", "Completed"],
      default: "Confirmed",
    },
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Payment",
      required: true,
    },
    reviews: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Review",
      },
    ],
  },
  { timestamps: true }
);

bookingSchema.index({ carVariant: 1, status: 1, startDate: 1, endDate: 1 });
bookingSchema.index({ renter: 1, createdAt: -1 });
bookingSchema.index({ payment: 1 }, { unique: true });

const Booking = mongoose.model("Booking", bookingSchema);

export default Booking;
