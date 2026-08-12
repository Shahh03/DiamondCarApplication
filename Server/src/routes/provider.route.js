import express from "express";

import {
  getAllProviders,
  getProviderbyId,
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
