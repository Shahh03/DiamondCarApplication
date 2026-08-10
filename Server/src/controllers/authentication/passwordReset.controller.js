import crypto from "node:crypto";

import mongoose from "mongoose";

import PasswordResetCode from "../../models/passwordResetCode.js";
import User from "../../models/user.js";
import { sendPasswordResetOtp } from "../../services/email.service.js";
import { hashPassword, verifyPassword } from "../../utils/password.js";

const OTP_LIFETIME_MS = 10 * 60 * 1000;
const RESET_TOKEN_LIFETIME_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const MINIMUM_RESPONSE_MS = 500;

const genericRequestResponse = {
  message: "If an account uses that email, a reset code has been sent.",
};

const delay = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

const finishAfterMinimumDelay = async (startedAt) => {
  const remaining = MINIMUM_RESPONSE_MS - (Date.now() - startedAt);
  if (remaining > 0) await delay(remaining);
};

const resetPepper = () => {
  if (!process.env.PASSWORD_RESET_PEPPER) {
    const error = new Error("PASSWORD_RESET_PEPPER is not configured");
    error.statusCode = 500;
    throw error;
  }
  return process.env.PASSWORD_RESET_PEPPER;
};

const hashOtp = (recordId, otp) =>
  crypto
    .createHmac("sha256", resetPepper())
    .update(`${recordId}:${otp}`)
    .digest("hex");

const hashResetToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const hashesMatch = (left, right) => {
  if (!left || !right) return false;
  const leftBuffer = Buffer.from(left, "hex");
  const rightBuffer = Buffer.from(right, "hex");
  return (
    leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer)
  );
};

const validEmail = (value) =>
  typeof value === "string" &&
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());

const validateNewPassword = (password) => {
  if (typeof password !== "string" || password.length < 8) {
    return "Password must be at least 8 characters";
  }
  if (Buffer.byteLength(password, "utf8") > 72) {
    return "Password must not exceed 72 bytes";
  }
  return null;
};

export const requestPasswordReset = async (req, res) => {
  const startedAt = Date.now();
  const email = req.body.email?.trim().toLowerCase();
  const isProduction = process.env.NODE_ENV === "production";

  if (!validEmail(email)) {
    return res.status(400).json({
      message: "Enter a valid email address",
    });
  }

  try {
    resetPepper();

    // Renter and Provider discriminators are stored in the User collection.
    const user = await User.findOne({
      email,
      type: {
        $in: ["Renter", "Provider"],
      },
    }).select("_id email type");

    if (!isProduction) {
      console.log("Password reset account lookup:", {
        accountFound: Boolean(user),
        accountType: user?.type ?? null,
      });
    }

    if (!user) {
      await finishAfterMinimumDelay(startedAt);

      // Helpful during development, but unsafe for production because it
      // exposes which emails have DiamondCar accounts.
      if (!isProduction) {
        return res.status(404).json({
          message: "No account associated with that email was found",
        });
      }

      return res.status(200).json(genericRequestResponse);
    }

    const recentRequest = await PasswordResetCode.exists({
      user: user._id,
      usedAt: null,
      createdAt: {
        $gt: new Date(Date.now() - RESEND_COOLDOWN_MS),
      },
    });

    if (recentRequest) {
      await finishAfterMinimumDelay(startedAt);

      return res.status(200).json({
        message: "A code was recently sent. Please wait before requesting another.",
      });
    }

    const now = new Date();

    // Invalidate every older unused reset request.
    await PasswordResetCode.updateMany(
      {
        user: user._id,
        usedAt: null,
      },
      {
        $set: {
          usedAt: now,
        },
      },
    );

    const otp = crypto
      .randomInt(0, 1_000_000)
      .toString()
      .padStart(6, "0");

    const recordId = new mongoose.Types.ObjectId();

    const resetRecord = await PasswordResetCode.create({
      _id: recordId,
      user: user._id,
      email: user.email,
      otpHash: hashOtp(recordId, otp),
      otpExpiresAt: new Date(Date.now() + OTP_LIFETIME_MS),
    });

    try {
      await sendPasswordResetOtp({
        to: user.email,
        otp,
      });
    } catch (emailError) {
      // Do not leave a usable OTP when its email was never delivered.
      await PasswordResetCode.deleteOne({
        _id: resetRecord._id,
      });

      console.error("Password reset email error:", emailError);

      await finishAfterMinimumDelay(startedAt);

      if (!isProduction) {
        return res.status(502).json({
          message:
              "The account exists, but the email service could not send the code. Check the server terminal.",
        });
      }

      return res.status(200).json(genericRequestResponse);
    }

    if (!isProduction) {
      console.log("Password reset email submitted successfully:", {
        accountType: user.type,
      });
    }

    await finishAfterMinimumDelay(startedAt);

    return res.status(200).json(genericRequestResponse);
  } catch (error) {
    console.error("Request password reset error:", error);

    await finishAfterMinimumDelay(startedAt);

    return res.status(error.statusCode || 500).json({
      message: error.statusCode
          ? error.message
          : "Could not process the reset request",
    });
  }
};

export const verifyPasswordResetOtp = async (req, res) => {
  const email = req.body.email?.trim().toLowerCase();
  const otp = req.body.otp?.trim();

  if (!validEmail(email) || !/^\d{6}$/.test(otp ?? "")) {
    return res.status(400).json({ message: "Invalid or expired code" });
  }

  try {
    const resetRecord = await PasswordResetCode.findOne({
      email,
      usedAt: null,
      verifiedAt: null,
      otpExpiresAt: { $gt: new Date() },
    })
      .sort({ createdAt: -1 })
      .select("+otpHash");

    if (!resetRecord || resetRecord.attempts >= MAX_OTP_ATTEMPTS) {
      return res.status(400).json({ message: "Invalid or expired code" });
    }

    const submittedHash = hashOtp(resetRecord._id, otp);
    if (!hashesMatch(submittedHash, resetRecord.otpHash)) {
      resetRecord.attempts += 1;
      if (resetRecord.attempts >= MAX_OTP_ATTEMPTS) {
        resetRecord.usedAt = new Date();
      }
      await resetRecord.save();
      return res.status(400).json({ message: "Invalid or expired code" });
    }

    const resetToken = crypto.randomBytes(32).toString("hex");
    resetRecord.verifiedAt = new Date();
    resetRecord.resetTokenHash = hashResetToken(resetToken);
    resetRecord.resetTokenExpiresAt = new Date(
      Date.now() + RESET_TOKEN_LIFETIME_MS
    );
    await resetRecord.save();

    return res.status(200).json({
      message: "Code verified",
      resetToken,
      expiresInSeconds: RESET_TOKEN_LIFETIME_MS / 1000,
    });
  } catch (error) {
    console.error("Verify password reset OTP error:", error);
    return res.status(500).json({ message: "Could not verify the code" });
  }
};

export const completePasswordReset = async (req, res) => {
  const { resetToken, newPassword } = req.body;
  const passwordError = validateNewPassword(newPassword);

  if (typeof resetToken !== "string" || !resetToken || passwordError) {
    return res.status(400).json({
      message: passwordError ?? "Reset session is invalid or expired",
    });
  }

  try {
    const now = new Date();
    const resetRecord = await PasswordResetCode.findOneAndUpdate(
      {
        resetTokenHash: hashResetToken(resetToken),
        verifiedAt: { $ne: null },
        resetTokenExpiresAt: { $gt: now },
        usedAt: null,
      },
      { $set: { usedAt: now } },
      { new: true }
    );

    if (!resetRecord) {
      return res.status(400).json({
        message: "Reset session is invalid or expired",
      });
    }

    const user = await User.findById(resetRecord.user).select(
      "+password +refreshTokens"
    );
    if (!user) {
      return res.status(400).json({
        message: "Reset session is invalid or expired",
      });
    }

    if (await verifyPassword(newPassword, user.password)) {
      return res.status(400).json({
        message: "New password cannot be the same as the current password",
      });
    }

    user.password = await hashPassword(newPassword);
    user.refreshTokens = [];
    await user.save();

    await PasswordResetCode.updateMany(
      { user: user._id, usedAt: null },
      { $set: { usedAt: new Date() } }
    );

    return res.status(200).json({
      message: "Password updated successfully. You can now sign in.",
    });
  } catch (error) {
    console.error("Complete password reset error:", error);
    return res.status(500).json({ message: "Could not reset the password" });
  }
};
