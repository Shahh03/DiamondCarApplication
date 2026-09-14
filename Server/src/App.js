import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";
import morgan from "morgan";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import multer from "multer";
import fs from "fs";

import { captureServerFailure, monitorServerResponses } from "./config/sentry.js";

import initializeRoutes from "./routes/routes.js";
import { stripeWebhook } from "./controllers/payment/payment.controller.js";

const __filename = fileURLToPath(import.meta.url);
const currentDir = path.dirname(__filename);
const envPath = path.join(currentDir, "..", ".env");

console.log("Looking for .env at:", envPath);
console.log(".env exists?", fs.existsSync(envPath));

dotenv.config({ path: envPath });

class App {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 8000;
    this.DB = process.env.MONGO_URI;
    this.env = process.env.NODE_ENV || "development";

    console.log("MONGO_URI loaded?", !!process.env.MONGO_URI);
    console.log("Cloudinary loaded?", !!process.env.CLOUDINARY_CLOUD_NAME);
    console.log("Stripe loaded?", !!process.env.STRIPE_SECRET_KEY);

    this.__dirname = currentDir;
  }

  async connectToDatabase() {
    if (this.env === "development") {
      this.app.use(morgan("dev"));
    }

    if (!this.DB) {
      console.error("MONGO_URI is missing. Check your Server/.env file.");
      throw new Error("MONGO_URI is missing");
    }

    try {
      await mongoose.connect(this.DB);
      console.log("MongoDB connected successfully!");
    } catch (error) {
      console.error("MongoDB connection error:", error);
      throw error;
    }
  }

  initializeMiddlewares() {
    this.app.use(monitorServerResponses);
    this.app.use(cors());

    // Stripe must receive the exact, unparsed request bytes to verify the
    // Stripe-Signature header. Keep this route before express.json().
    this.app.post(
      "/stripe/webhook",
      express.raw({ type: "application/json" }),
      stripeWebhook
    );

    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));

    this.app.use(
      "/uploads",
      express.static(path.join(this.__dirname, "uploads"))
    );

    initializeRoutes(this.app);

    this.app.use((err, req, res, next) => {
      if (err.code === "UNSUPPORTED_FILE_TYPE") {
        return res.status(415).json({
          error:
            "Only JPG, JPEG, PNG, HEIC, HEIF, WEBP, GIF, or DNG are allowed.",
        });
      }

      if (err.code === "LIMIT_FILE_SIZE") {
        return res.status(413).json({ error: "File too large." });
      }

      if (err instanceof multer.MulterError) {
        return res.status(400).json({ error: err.message });
      }

      console.error(err);
      res.locals.sentryReported = true;
      captureServerFailure(err, "express-error-handler");
      if (res.headersSent) return next(err);
      return res.status(500).json({ error: "Internal server error" });
    });
  }

  listen() {
    this.app.listen(this.port, () => {
      console.log(`🚀 Server is running on port ${this.port}`);
    });
  }

  getServer() {
    return this.app;
  }
}

export default App;
