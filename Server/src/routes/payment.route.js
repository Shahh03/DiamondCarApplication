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
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireBodyOwner,
  requireParamOwner,
  requireRole,
} from "../middlewares/authorization.js";

const router = express.Router();

router.post(
  "/stripe/payment-intent",
  authenticateAccessToken,
  requireBodyOwner({ field: "renter", type: "Renter" }),
  createStripePaymentIntent
);
router.get(
  "/stripe/payment-status/:paymentIntentId",
  authenticateAccessToken,
  requireRole("Renter", "Admin"),
  getStripePaymentStatus
);
router.put(
  "/stripe/refund/:paymentId",
  authenticateAccessToken,
  requireRole("Admin"),
  refundPayment
);

router.post(
  "/stripe/setup-intent",
  authenticateAccessToken,
  requireBodyOwner({ field: "renterId", type: "Renter" }),
  createCardSetupIntent
);
router.get(
  "/stripe/payment-methods/:renterId",
  authenticateAccessToken,
  requireParamOwner({ parameter: "renterId", type: "Renter" }),
  getSavedPaymentMethods
);
router.put(
  "/stripe/payment-methods/default",
  authenticateAccessToken,
  requireBodyOwner({ field: "renterId", type: "Renter" }),
  setDefaultPaymentMethod
);
router.delete(
  "/stripe/payment-methods/:renterId/:paymentMethodId",
  authenticateAccessToken,
  requireParamOwner({ parameter: "renterId", type: "Renter" }),
  removeSavedPaymentMethod
);

export default router;
