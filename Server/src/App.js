import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";
import morgan from "morgan";
import initializeRoutes from "./routes/routes.js";
import cors from "cors";
import path from "path"; // Import path module
import { fileURLToPath } from "url"; // Import fileURLToPath for getting the directory name
import multer from 'multer';


dotenv.config(); // Load environment variables

class App {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 8000;
    this.DB = "mongodb+srv://Ahmed:Ahmedhany1@diamondcar.cptnu.mongodb.net/?retryWrites=true&w=majority&appName=DiamondCar"
    this.env = process.env.NODE_ENV || "development";

    this.__dirname = path.dirname(fileURLToPath(import.meta.url)); // Set __dirname
  }

  // Connect to MongoDB
  async connectToDatabase() {
    if (this.env === "development") {
      this.app.use(morgan("dev"));
    }
    await mongoose
      .connect(this.DB)
      .then(() => {
        console.log("MongoDB connected successfully!");
      })
      .catch((err) => {
        console.error("MongoDB connection error:", err);
      });
  }

  // Middlewares (CORS, JSON parsing, etc.)
  initializeMiddlewares() {
    // Enable CORS for all routes
    this.app.use(cors());
    this.app.use(express.json()); // Parse incoming JSON requests

    this.app.use((err, req, res, next) => {
        if (err.code === 'UNSUPPORTED_FILE_TYPE') {
          return res.status(415).json({
            error: 'Only JPG, JPEG, PNG, HEIC, HEIF, WEBP, GIF, or DNG are allowed.',
          });
        }
        if (err.code === 'LIMIT_FILE_SIZE') {
          return res.status(413).json({ error: 'File too large.' });
        }
        if (err instanceof multer.MulterError) {
          return res.status(400).json({ error: err.message });
        }
        next(err);
      });

    // Serve static files from the 'uploads' directory
    this.app.use("/uploads", express.static(path.join(this.__dirname, "uploads")));

    initializeRoutes(this.app); // Initialize routes
  }

  // Start the server
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
