import express from "express";
import rateLimit from "express-rate-limit";

import {
  completePasswordReset,
  requestPasswordReset,
  verifyPasswordResetOtp,
} from "../controllers/authentication/passwordReset.controller.js";

const router = express.Router();

const requestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Too many reset requests. Please try again later." },
});

const verificationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Too many attempts. Please try again later." },
});

router.post(
  "/user/password-reset/request",
  requestLimiter,
  requestPasswordReset
);
router.post(
  "/user/password-reset/verify",
  verificationLimiter,
  verifyPasswordResetOtp
);
router.post(
  "/user/password-reset/complete",
  verificationLimiter,
  completePasswordReset
);

export default router;
