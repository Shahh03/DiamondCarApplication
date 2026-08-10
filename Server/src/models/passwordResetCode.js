import mongoose from "mongoose";

const passwordResetCodeSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    email: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
      index: true,
    },
    otpHash: {
      type: String,
      required: true,
      select: false,
    },
    otpExpiresAt: {
      type: Date,
      required: true,
    },
    attempts: {
      type: Number,
      default: 0,
      min: 0,
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    resetTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    resetTokenExpiresAt: {
      type: Date,
      default: null,
    },
    usedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

passwordResetCodeSchema.index({ email: 1, createdAt: -1 });
passwordResetCodeSchema.index(
  { createdAt: 1 },
  { expireAfterSeconds: 60 * 60 }
);

const PasswordResetCode = mongoose.model(
  "PasswordResetCode",
  passwordResetCodeSchema
);

export default PasswordResetCode;
