import { v2 as cloudinary } from "cloudinary";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const currentDir = path.dirname(__filename);

// cloudinary.js is in Server/src/config
// so we go back to Server/.env
dotenv.config({
  path: path.join(currentDir, "..", "..", ".env"),
});

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

console.log("Cloudinary cloud name:", process.env.CLOUDINARY_CLOUD_NAME);

export default cloudinary;