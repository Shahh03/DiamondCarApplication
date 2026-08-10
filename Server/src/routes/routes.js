
import bookingRoute from "./booking.route.js";
import carRoute from "./car.route.js";
import complaintRoute from "./complant.route.js";
import paymentRoute from "./payment.route.js";
import providerRoute from "./provider.route.js";
import renterRoute from "./renter.route.js";
import reviewRoute from "./review.route.js";
import userRoute from "./user.route.js";
import carVariantRoute from "./carVariant.route.js";
import activityRoute from "./activity.route.js";
import passwordResetRoute from "./passwordReset.route.js";

export default (app) => {
  app.use(bookingRoute);
  app.use(carRoute);
  app.use(complaintRoute);
  app.use(paymentRoute);
  app.use(providerRoute);
  app.use(renterRoute);
  app.use(reviewRoute);
  app.use(userRoute);
  app.use(carVariantRoute);
  app.use(activityRoute);
  app.use(passwordResetRoute);

};
