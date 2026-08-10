import express from "express";

import {
  createCarVariant,
  getAllAvaiableCarVariants,
  getAllCarsForProvider,
  getCarVariantByID,
  getCarVariantsByCarId,
  getRecommendedCarVariants,
  uploadCarVariantImages,
} from "../controllers/carVariant/carVariant.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireAcceptedProvider,
  requireBodyOwner,
  requireCarVariantProvider,
  requireParamOwner,
} from "../middlewares/authorization.js";
import { carUpload } from "../middlewares/upload.js";

const router = express.Router();

// Public catalogue endpoints.
router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId);
router.get("/carVariant/getAllAvailable", getAllAvaiableCarVariants);

// Personalized renter endpoint.
router.get(
  "/carVariant/recommended/:renterId",
  authenticateAccessToken,
  requireParamOwner({ parameter: "renterId", type: "Renter" }),
  getRecommendedCarVariants
);

// Provider-owned inventory endpoints.
router.post(
  "/carVariant/create",
  authenticateAccessToken,
  requireBodyOwner({ field: "provider", type: "Provider", allowAdmin: true }),
  requireAcceptedProvider,
  createCarVariant
);
router.get(
  "/carVariant/getAllCarsForProvider/:providerId",
  authenticateAccessToken,
  requireParamOwner({
    parameter: "providerId",
    type: "Provider",
    allowAdmin: true,
  }),
  getAllCarsForProvider
);
router.post(
  "/carVariant/uploadCarVariantImages/:carVariantId",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  // Ownership is checked before Multer accepts image bytes.
  carUpload.array("files", 10),
  uploadCarVariantImages
);

// Keep the dynamic route last.
router.get("/carVariant/:carVariantId", getCarVariantByID);

export default router;
