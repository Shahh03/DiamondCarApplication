import mongoose from "mongoose";

const carVariantSchema = new mongoose.Schema(
  {
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Provider",
      required: true,
    },
    car: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Car",
      required: true,
    },
    color: {
      type: String,
      required: true,
      trim: true,
    },
    registrationNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    rentalPricePerDay: {
      type: Number,
      required: true,
      min: 0,
    },
    depositAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    isAvailable: {
      type: Boolean,
      default: true,
    },
    insuranceDetails: {
      insuranceCompany: { type: String, trim: true },
      policyNumber: { type: String, trim: true },
      expiryDate: { type: Date },
    },
    maintenanceRecords: [
      {
        serviceDate: { type: Date },
        details: { type: String, trim: true },
        serviceCenter: { type: String, trim: true },
      },
    ],
    images: [{ type: String, trim: true }],
    imagePublicIds: [{ type: String, trim: true }],
  },
  { timestamps: true }
);

carVariantSchema.index({ isAvailable: 1, rentalPricePerDay: 1 });
carVariantSchema.index({ provider: 1, isAvailable: 1 });
carVariantSchema.index({ car: 1, isAvailable: 1 });

const CarVariant = mongoose.model("CarVariant", carVariantSchema);

export default CarVariant;