import mongoose from "mongoose";

const bookingSchema = new mongoose.Schema({
  renter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Renter",
    required: true,
  },
  // provider: {
  //   type: mongoose.Schema.Types.ObjectId,
  //   ref: "Provider",
  //   required: true,
  // },
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
  },
  status: {
    type: String,
    enum: ["Confirmed", "Cancelled", "Completed"],
    default: "Confirmed",
  },
  payment: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Payment",
    required: true
  },
  reviews: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Review",
    },
  ],
  createdAt: {
    type: Date,
    default: Date.now,
  },
});


const Booking = mongoose.model("Booking", bookingSchema);

export default Booking;
