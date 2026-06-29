import mongoose from "mongoose";

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
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
});

const User = mongoose.model("User", userSchema);
export default User;