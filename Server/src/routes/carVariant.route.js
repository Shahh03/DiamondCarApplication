import express from "express";

import {
  archiveCarVariant,
  createCarVariant,
  getAllAvaiableCarVariants,
  getAllCarsForProvider,
  getCarVariantByID,
  getCarVariantsByCarId,
  getRecommendedCarVariants,
  removeCarVariantImage,
  reorderCarVariantImages,
  updateCarVariant,
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

router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId);
router.get("/carVariant/getAllAvailable", getAllAvaiableCarVariants);

router.get(
  "/carVariant/recommended/:renterId",
  authenticateAccessToken,
  requireParamOwner({ parameter: "renterId", type: "Renter" }),
  getRecommendedCarVariants
);

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

router.put(
  "/carVariant/update/:carVariantId",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  updateCarVariant
);

router.post(
  "/carVariant/uploadCarVariantImages/:carVariantId",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  carUpload.array("files", 10),
  uploadCarVariantImages
);

router.put(
  "/carVariant/:carVariantId/images/order",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  reorderCarVariantImages
);

router.delete(
  "/carVariant/:carVariantId/image",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  removeCarVariantImage
);

router.delete(
  "/carVariant/:carVariantId",
  authenticateAccessToken,
  requireCarVariantProvider,
  requireAcceptedProvider,
  archiveCarVariant
);

// Keep the dynamic public route last.
router.get("/carVariant/:carVariantId", getCarVariantByID);

export default router;
