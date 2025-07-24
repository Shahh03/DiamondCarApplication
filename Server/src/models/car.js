import mongoose from "mongoose";

const carSchema = new mongoose.Schema({
  brand: {
    type: String,
    required: true,
  },
  model: {
    type: String,
    required: true,
  },
  year: {
    type: Number,
    required: true,
  },
  category: {
    type: String,
    enum: ["Sedan", "SUV", "Hatchback", "Convertible", "Luxury", "Van", "Truck"],
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
  },
  features: {
    type: [String], // Example: ["Air Conditioning", "GPS", "Bluetooth"]
  },
  reviews: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Review",
    },
  ]
  
});


const Car = mongoose.model("Car", carSchema);

export default Car;
