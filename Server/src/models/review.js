import mongoose from "mongoose";

const reviewSchema = new mongoose.Schema({
  renter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Renter", // The reviewer is a renter
    required: true,
  },
  reviewType: {
    type: String,
    enum: ["Provider", "Car", "Booking"], // Review can be for a provider, car, or booking
    required: true,
  },
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Provider",
    required: function() { return this.reviewType === "Provider"; }, // Only required if it's a provider review
  },
  car: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Car",
    required: function() { return this.reviewType === "Car"; }, // Only required if it's a car review
  },
  booking: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Booking",
    required: function() { return this.reviewType === "Booking"; }, // Only required if it's a booking review
  },
  rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5, // Rating out of 5
  },
  comment: {
    type: String,
  },
  date: {
    type: Date,
    default: Date.now,
  },
});

const Review = mongoose.model("Review", reviewSchema);

export default Review;
