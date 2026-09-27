import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    recipientType: {
      type: String,
      enum: ["Renter", "Provider", "Admin"],
      required: true,
    },
    type: {
      type: String,
      enum: [
        "BookingConfirmed",
        "BookingCancelled",
        "ProviderApproved",
        "ProviderRejected",
        "VehicleApproved",
        "VehicleRejected",
      ],
      required: true,
    },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    message: { type: String, required: true, trim: true, maxlength: 500 },
    actionUrl: { type: String, default: "", trim: true, maxlength: 500 },
    isRead: { type: Boolean, default: false, index: true },
    readAt: { type: Date, default: null },
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Booking",
      default: null,
    },
    carVariant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "CarVariant",
      default: null,
    },
    dedupeKey: { type: String, required: true, unique: true, index: true },
  },
  { timestamps: true }
);

notificationSchema.index({ recipient: 1, isRead: 1, createdAt: -1 });
notificationSchema.index({ recipient: 1, createdAt: -1 });

const Notification = mongoose.model("Notification", notificationSchema);

export default Notification;
