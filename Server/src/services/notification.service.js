import Notification from "../models/notification.js";

export const createNotification = async (notification, options = {}) => {
  const queryOptions = { upsert: true };
  if (options.session) queryOptions.session = options.session;

  return Notification.updateOne(
    { dedupeKey: notification.dedupeKey },
    { $setOnInsert: notification },
    queryOptions
  );
};

export const notifyBookingConfirmed = ({
  bookingId,
  providerId,
  carVariantId,
  renterName,
  vehicleName,
  session,
}) =>
  createNotification(
    {
      recipient: providerId,
      recipientType: "Provider",
      type: "BookingConfirmed",
      title: "New booking received",
      message: `${renterName || "A renter"} booked your ${vehicleName || "vehicle"}.`,
      actionUrl: `/provider/bookings?booking=${bookingId}`,
      booking: bookingId,
      carVariant: carVariantId,
      dedupeKey: `booking-confirmed:${bookingId}`,
    },
    { session }
  );

export const notifyProviderReviewed = ({ providerId, decision }) =>
  createNotification({
    recipient: providerId,
    recipientType: "Provider",
    type: decision === "Accepted" ? "ProviderApproved" : "ProviderRejected",
    title:
      decision === "Accepted"
        ? "Provider account approved"
        : "Provider application update",
    message:
      decision === "Accepted"
        ? "Your provider account has been approved. You can now manage your fleet and bookings."
        : "Your provider application was not approved. Review your company details or contact support.",
    actionUrl:
      decision === "Accepted" ? "/provider/dashboard" : "/provider/company",
    dedupeKey: `provider-review:${providerId}:${decision}`,
  });

export const notifyVehicleReviewed = ({
  providerId,
  carVariantId,
  decision,
  vehicleName,
  registrationNumber,
  rejectionReason,
  submittedAt,
}) => {
  const approved = decision === "Approved";
  const vehicle = vehicleName || "vehicle";
  const registration = registrationNumber
    ? ` (${registrationNumber})`
    : "";
  const reason = rejectionReason?.toString().trim().slice(0, 300);
  const submittedDate = submittedAt ? new Date(submittedAt) : null;
  const reviewCycle =
    submittedDate && !Number.isNaN(submittedDate.getTime())
      ? submittedDate.toISOString()
      : "initial";

  return createNotification({
    recipient: providerId,
    recipientType: "Provider",
    type: approved ? "VehicleApproved" : "VehicleRejected",
    title: approved ? "Vehicle approved" : "Vehicle needs attention",
    message: approved
      ? `Your ${vehicle}${registration} has been approved and is now visible to renters.`
      : `Your ${vehicle}${registration} was not approved. Reason: ${
          reason || "Review the vehicle details and submit it again."
        }`,
    actionUrl: "/provider/fleet",
    carVariant: carVariantId,
    dedupeKey: `vehicle-review:${carVariantId}:${reviewCycle}:${decision}`,
  });
};
