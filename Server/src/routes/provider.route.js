import express from "express";
import { getCompany, updateCompany, uploadCompanyPhoto } from "../controllers/provider/providerCompany.controller.js";
import { renterUpload } from "../middlewares/upload.js";

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

const companyOwner = requireParamOwner({ parameter: "providerId", type: "Provider" });
router.get("/provider/company/:providerId", authenticateAccessToken, companyOwner, getCompany);
router.put("/provider/company/:providerId", authenticateAccessToken, companyOwner, updateCompany);
router.put("/provider/company/:providerId/photo", authenticateAccessToken, companyOwner,
  (req, res, next) => renterUpload.single("profilePicture")(req, res, (error) => {
    if (error) return res.status(400).json({ message: error.code === "LIMIT_FILE_SIZE"
      ? "Choose an image smaller than 10 MB." : "Choose one valid image (JPG, PNG or WebP)." });
    return next();
  }), uploadCompanyPhoto);

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
