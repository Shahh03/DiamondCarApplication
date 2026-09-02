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
    color: { type: String, required: true, trim: true },
    registrationNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    rentalPricePerDay: { type: Number, required: true, min: 0 },
    depositAmount: { type: Number, required: true, min: 0 },
    isAvailable: { type: Boolean, default: true },
    isListed: { type: Boolean, default: false, index: true },
    archivedAt: { type: Date, default: null },
    approvalStatus: {
      type: String,
      enum: ["Pending", "Approved", "Rejected"],
      // Legacy vehicles were already public before this workflow existed.
      // New provider submissions explicitly set Pending in the controller.
      default: "Approved",
      index: true,
    },
    submittedAt: { type: Date, default: Date.now },
    reviewedAt: { type: Date, default: null },
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    rejectionReason: { type: String, default: "", trim: true },
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

carVariantSchema.index({
  approvalStatus: 1,
  isListed: 1,
  isAvailable: 1,
  rentalPricePerDay: 1,
});
carVariantSchema.index({ provider: 1, approvalStatus: 1, archivedAt: 1 });
carVariantSchema.index({ car: 1, isListed: 1, isAvailable: 1 });

const CarVariant = mongoose.model("CarVariant", carVariantSchema);

export default CarVariant;
