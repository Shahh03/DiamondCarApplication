import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";
import morgan from "morgan";
import initializeRoutes from "./routes/routes.js";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import multer from "multer";
import fs from "fs";

const __filename = fileURLToPath(import.meta.url);
const currentDir = path.dirname(__filename);

const envPath = path.join(currentDir, "..", ".env");

console.log("Looking for .env at:", envPath);
console.log(".env exists?", fs.existsSync(envPath));

dotenv.config({
  path: envPath,
});

class App {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 8000;
    this.DB = process.env.MONGO_URI;
    this.env = process.env.NODE_ENV || "development";

    console.log("MONGO_URI loaded?", !!process.env.MONGO_URI);
    console.log("Cloudinary loaded?", !!process.env.CLOUDINARY_CLOUD_NAME);

    this.__dirname = currentDir;
  }

  async connectToDatabase() {
    if (this.env === "development") {
      this.app.use(morgan("dev"));
    }

    if (!this.DB) {
      console.error("MONGO_URI is missing. Check your Server/.env file.");
      process.exit(1);
    }

    await mongoose
      .connect(this.DB)
      .then(() => {
        console.log("MongoDB connected successfully!");
      })
      .catch((err) => {
        console.error("MongoDB connection error:", err);
        process.exit(1);
      });
  }

  initializeMiddlewares() {
    this.app.use(cors());
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
        return res.status(413).json({
          error: "File too large.",
        });
      }

      if (err instanceof multer.MulterError) {
        return res.status(400).json({
          error: err.message,
        });
      }

      console.error(err);

      return res.status(500).json({
        error: "Internal server error",
      });
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