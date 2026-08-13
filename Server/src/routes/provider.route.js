import express from "express";

import {
  getAllProviders,
  getProviderbyId,
  getProviderDashboard,
} from "../controllers/provider/provider.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireParamOwner,
  requireRole,
} from "../middlewares/authorization.js";

const router = express.Router();

router.get(
  "/provider/getAll",
  authenticateAccessToken,
  requireRole("Admin"),
  getAllProviders
);

router.get(
  "/provider/dashboard/:providerId",
  authenticateAccessToken,
  requireParamOwner({
    parameter: "providerId",
    type: "Provider",
    allowAdmin: true,
  }),
  getProviderDashboard
);

router.get(
  "/provider/get/:providerId",
  authenticateAccessToken,
  requireParamOwner({
    parameter: "providerId",
    type: "Provider",
    allowAdmin: true,
  }),
  getProviderbyId
);

export default router;
