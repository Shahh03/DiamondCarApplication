import jwt from "jsonwebtoken";
import mongoose from "mongoose";
import Stripe from "stripe";

import cloudinary from "./cloudinary.js";
import { verifyEmailTransport } from "../services/email.service.js";

const CHECK_TIMEOUT_MS = 5_000;

const status = Object.freeze({
  ready: "READY",
  disabled: "DISABLED",
  missing: "NOT CONFIGURED",
  unreachable: "UNREACHABLE",
});

const result = (name, state, detail) => ({ name, state, detail });

const configured = (...keys) => keys.every((key) => Boolean(process.env[key]?.trim()));

const errorLabel = (error) =>
  error?.code?.toString() ||
  error?.type?.toString() ||
  error?.name?.toString() ||
  "Connection check failed";

const withTimeout = (operation, serviceName) =>
  Promise.race([
    operation,
    new Promise((_, reject) => {
      const timer = setTimeout(() => {
        const error = new Error(`${serviceName} check timed out`);
        error.code = "TIMEOUT";
        reject(error);
      }, CHECK_TIMEOUT_MS);
      timer.unref?.();
    }),
  ]);

const checkMongoDB = async () => {
  if (mongoose.connection.readyState === 1) {
    return result("MongoDB", status.ready, "Connected");
  }
  return result("MongoDB", status.unreachable, "Not connected");
};

const checkCloudinary = async () => {
  if (
    !configured(
      "CLOUDINARY_CLOUD_NAME",
      "CLOUDINARY_API_KEY",
      "CLOUDINARY_API_SECRET"
    )
  ) {
    return result("Cloudinary", status.missing, "Credentials are incomplete");
  }

  try {
    await withTimeout(cloudinary.api.ping(), "Cloudinary");
    return result("Cloudinary", status.ready, "API reachable");
  } catch (error) {
    return result("Cloudinary", status.unreachable, errorLabel(error));
  }
};

const checkStripe = async () => {
  if (!configured("STRIPE_SECRET_KEY")) {
    return result("Stripe", status.missing, "Secret key is missing");
  }

  try {
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
      maxNetworkRetries: 0,
      timeout: CHECK_TIMEOUT_MS,
    });
    await stripe.balance.retrieve();
    return result("Stripe", status.ready, "API reachable");
  } catch (error) {
    return result("Stripe", status.unreachable, errorLabel(error));
  }
};

const checkSmtp = async () => {
  if (
    !configured(
      "SMTP_HOST",
      "SMTP_PORT",
      "SMTP_USER",
      "SMTP_PASS",
      "SMTP_FROM"
    )
  ) {
    return result("SMTP", status.missing, "Configuration is incomplete");
  }

  try {
    await withTimeout(verifyEmailTransport(), "SMTP");
    return result("SMTP", status.ready, "Authentication successful");
  } catch (error) {
    return result("SMTP", status.unreachable, errorLabel(error));
  }
};

const checkJwt = async () => {
  if (!configured("JWT_ACCESS_SECRET")) {
    return result("JWT", status.missing, "Access-token secret is missing");
  }

  try {
    const token = jwt.sign(
      { sub: "startup-health-check", type: "Admin" },
      process.env.JWT_ACCESS_SECRET,
      { algorithm: "HS256", expiresIn: "1m" }
    );
    jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      algorithms: ["HS256"],
    });
    return result("JWT", status.ready, "Signing and verification successful");
  } catch (error) {
    return result("JWT", status.unreachable, errorLabel(error));
  }
};

const checkSentry = async () => {
  if (process.env.SENTRY_ENABLED !== "true") {
    return result("Sentry", status.disabled, "Disabled by SENTRY_ENABLED");
  }
  if (!configured("SENTRY_DSN")) {
    return result("Sentry", status.missing, "DSN is missing");
  }
  return result("Sentry", status.ready, "Monitoring initialized");
};

const printReport = (results) => {
  const serviceWidth = Math.max(...results.map(({ name }) => name.length));
  const stateWidth = Math.max(...results.map(({ state }) => state.length));

  console.log("\nDiamondCar dependency status");
  console.log("-".repeat(72));
  for (const item of results) {
    console.log(
      `${item.name.padEnd(serviceWidth)}  ${item.state.padEnd(stateWidth)}  ${item.detail}`
    );
  }
  console.log("-".repeat(72));
};

export const reportStartupHealth = async () => {
  const results = await Promise.all([
    checkMongoDB(),
    checkCloudinary(),
    checkStripe(),
    checkSmtp(),
    checkJwt(),
    checkSentry(),
  ]);

  printReport(results);
  return results;
};
