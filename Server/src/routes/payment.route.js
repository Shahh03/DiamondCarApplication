import express from "express";

import {
  createCardSetupIntent,
  createStripePaymentIntent,
  getSavedPaymentMethods,
  getStripePaymentStatus,
  refundPayment,
  removeSavedPaymentMethod,
  setDefaultPaymentMethod,
} from "../controllers/payment/payment.controller.js";

const router = express.Router();

router.post("/stripe/payment-intent", createStripePaymentIntent);
router.get(
  "/stripe/payment-status/:paymentIntentId",
  getStripePaymentStatus
);
router.put("/stripe/refund/:paymentId", refundPayment);

router.post("/stripe/setup-intent", createCardSetupIntent);
router.get("/stripe/payment-methods/:renterId", getSavedPaymentMethods);
router.put("/stripe/payment-methods/default", setDefaultPaymentMethod);
router.delete(
  "/stripe/payment-methods/:renterId/:paymentMethodId",
  removeSavedPaymentMethod
);

export default router;
