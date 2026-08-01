import mongoose from "mongoose";

const searchDataSchema = new mongoose.Schema(
  {
    query: { type: String, trim: true, maxlength: 100 },
    brand: { type: String, trim: true, maxlength: 60 },
    category: { type: String, trim: true, maxlength: 40 },
    transmission: { type: String, trim: true, maxlength: 30 },
    fuelType: { type: String, trim: true, maxlength: 30 },
    minPrice: { type: Number, min: 0 },
    maxPrice: { type: Number, min: 0 },
    seats: { type: Number, min: 1, max: 100 },
  },
  { _id: false }
);

const userActivitySchema = new mongoose.Schema({
  renter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Renter",
    required: true,
    index: true,
  },
  eventType: {
    type: String,
    enum: ["view", "search", "filter"],
    required: true,
    index: true,
  },
  carVariant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "CarVariant",
    default: null,
  },
  searchData: {
    type: searchDataSchema,
    default: undefined,
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 60 * 60 * 24 * 90,
  },
});

userActivitySchema.index({ renter: 1, createdAt: -1 });
userActivitySchema.index({ renter: 1, eventType: 1, createdAt: -1 });
userActivitySchema.index({ renter: 1, carVariant: 1, createdAt: -1 });

const UserActivity = mongoose.model("UserActivity", userActivitySchema);

export default UserActivity;