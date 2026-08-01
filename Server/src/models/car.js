


import mongoose from "mongoose";

const carSchema = new mongoose.Schema(
  {
    brand: {
      type: String,
      required: true,
      trim: true,
    },
    model: {
      type: String,
      required: true,
      trim: true,
    },
    year: {
      type: Number,
      required: true,
      min: 1886,
    },
    category: {
      type: String,
      enum: [
        "Sedan",
        "SUV",
        "Hatchback",
        "Compact",
        "Convertible",
        "Luxury",
        "Sports",
        "Van",
        "Truck",
      ],
      required: true,
    },
    transmission: {
      type: String,
      enum: ["Manual", "Automatic"],
      required: true,
    },
    fuelType: {
      type: String,
      enum: ["Petrol", "Diesel", "Electric", "Hybrid"],
      required: true,
    },
    seats: {
      type: Number,
      required: true,
      min: 1,
      max: 100,
    },
    features: {
      type: [String],
      default: [],
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

carSchema.index({ brand: 1, model: 1, year: -1 });
carSchema.index({ category: 1, fuelType: 1, transmission: 1 });

const Car = mongoose.model("Car", carSchema);

export default Car;