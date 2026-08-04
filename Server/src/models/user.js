import mongoose from "mongoose";

const refreshTokenSchema = new mongoose.Schema(
  {
    tokenHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
  },
  password: {
    type: String,
    required: true,
    select: false,
  },
  type: {
    type: String,
    enum: ["Renter", "Provider", "Admin"],
    required: true,
  },
  hasAcceptedTerms: {
    type: Boolean,
    default: false,
  },
  usernameLastChangedAt: {
    type: Date,
    default: null,
  },
  usernameChangeCount: {
    type: Number,
    default: 0,
  },
  refreshTokens: {
    type: [refreshTokenSchema],
    default: [],
    select: false,
  },
});

const User = mongoose.model("User", userSchema);
export default User;
