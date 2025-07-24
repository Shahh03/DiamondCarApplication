import mongoose from "mongoose";
import User from "./user.js";

const providerSchema = new mongoose.Schema({
  companyName: {
    type: String,
    required: true,
  },
  contactPerson: {
    name: { type: String, required: true },
    phoneNumber: { type: String, required: true },
    email: { type: String, required: true },
  },
  address: {
    street: { type: String },
    city: { type: String, required: true },
    state: { type: String },
    country: { type: String, required: true },
    postalCode: { type: String },
  },
  registrationNumber: {
    type: String,
    required: true, // Business or company registration number
    unique: true,
  },
  status: {
    type: String,
    enum: ["Pending", "Rejected", "Accepted"],
    required: true,
    default: "Pending",
  },
  isVerified: {
    type: Boolean,
    default: false, // Verification status
  },
  verificationDocuments: {
    license: {
      filename: { type: String, required: true },
      filepath: { type: String, required: true },
    }, // Business license
    idCard: {
      filename: { type: String, required: true },
      filepath: { type: String, required: true },
    }, // Owner/Representative ID
  },
  listedCars: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Car", // Reference to Car model
    },
  ],
  reviews: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Review",
    },
  ],
  bankDetails: {
    accountHolderName: { type: String, required: true },
    accountNumber: { type: String, required: true },
    bankName: { type: String, required: true },
    IBAN: { type: String },
    swiftCode: { type: String },
  },
  profilePicture: {
    filename: String,
    filepath: String, // Stores the profile image of the provider
  },
});

// Use User discriminator for Provider schema
const Provider = User.discriminator("Provider", providerSchema);

export default Provider;
