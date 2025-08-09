import mongoose from "mongoose";
import User from "./user.js";

const renterSchema = new mongoose.Schema({
  phoneNumber: {
    type: String,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  nationality: {
    type: String,
    required: true,
  },
  birthDate: {
    type: Date,
    required: true,
  },
  occupation: {
    type: String,
    required: true,
  },
  gender: {
    type: String,
    enum: ["Male", "Female"],
    required: true
  },
  isVerified: {
    type: Boolean,
    default: false,
  },

    drivingLicenseNumber: {
      type: String,
      required: true
    },
    idCardNumber: { 
      type: String,
      required: true
    },
    location:{
      type: String,
      required: true
    },
    wishlist: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "CarVariant",
      },
    ],
  complaints: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Complaint",
    },
  ],

  profilePicture: {
    filename: String,
    filepath: String, // This will store the path or URL to the profile picture
  },
  driverLicensePicture: {
    filename: String,
    filepath: String, // This will store the path or URL to the profile picture
  },
  idPicture: {
    filename: String,
    filepath: String, // This will store the path or URL to the profile picture
  },
  currency: {
    type: String,
    enum: ["USD", "CAD", "GBP", "EUR", "AUD", "EGP","AED", "SAR", "QAR", "OMR", "BHD"],
    default: "EGP"
  },


});



const Renter = User.discriminator("Renter", renterSchema);

export default Renter;