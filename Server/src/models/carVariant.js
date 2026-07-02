import mongoose from "mongoose";

// CarVariant Schema: Represents a car with a specific provider's details
const carVariantSchema = new mongoose.Schema({
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Provider",
    required: true,
  },
  car: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Car", // References the base Car document
    required: true,
  },
  color: {
    type: String,
    required: true, // The color of the car variant
  },
  registrationNumber: {
    type: String,
    required: true,
    unique: true, // Ensures no duplicate registration numbers
  },
  rentalPricePerDay: {
    type: Number,
    required: true,
  },
  depositAmount: {
    type: Number,
    required: true,
  },
  isAvailable: {
    type: Boolean,
    default: true, // Tracks if the car is available for rent
  },
  insuranceDetails: {
    insuranceCompany: { type: String },
    policyNumber: { type: String },
    expiryDate: { type: Date },
  },
  maintenanceRecords: [
    {
      serviceDate: { type: Date },
      details: { type: String },
      serviceCenter: { type: String },
    },
  ],
  images: [
    {
      type: String,
    },
  ],

imagePublicIds: [       // Cloudinary public_ids for deletion
    {
      type: String,
    },
  ],      
});

const CarVariant = mongoose.model("CarVariant", carVariantSchema);

export default CarVariant;
