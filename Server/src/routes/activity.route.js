import express from "express";

import {
  getRecentlyViewedCarVariants,
  trackUserActivity,
} from "../controllers/activity/activity.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireBodyOwner,
  requireParamOwner,
} from "../middlewares/authorization.js";

const router = express.Router();

router.post(
  "/activity/track",
  authenticateAccessToken,
  requireBodyOwner({ field: "renterId", type: "Renter" }),
  trackUserActivity
);
router.get(
  "/activity/recently-viewed/:renterId",
  authenticateAccessToken,
  requireParamOwner({ parameter: "renterId", type: "Renter" }),
  getRecentlyViewedCarVariants
);

export default router;
