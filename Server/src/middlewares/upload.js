import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// Directories setup (unchanged)
const baseDir = path.join(__dirname, '..', 'uploads', 'renters');
const profileDir = path.join(baseDir, 'profile');
[baseDir, profileDir].forEach((p) => {
  if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
});

// Allowed mime types and extensions for mobile photos
const allowedMimes = new Set([
  'image/jpeg', 'image/png', 'image/heic',
  'image/heif', 'image/webp', 'image/gif',
  'image/x-adobe-dng', 'image/dng'
]);

const allowedExts = new Set([
  '.jpg', '.jpeg', '.png', '.heic', '.heif',
  '.webp', '.gif', '.dng'
]);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profileDir),
  filename: (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  cb(null, `renter_${req.params.renterId}_${Date.now()}${ext}`);
}

});

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname || '').toLowerCase();
  const mimeOk = allowedMimes.has(file.mimetype);
  const extOk  = allowedExts.has(ext);

  if (!mimeOk || !extOk) {
    const err = new Error(
      'Unsupported file type. Allowed: JPG, JPEG, PNG, HEIC, HEIF, WEBP, GIF, DNG'
    );
    err.code = 'UNSUPPORTED_FILE_TYPE';
    return cb(err);
  }
  cb(null, true);
};

export const renterUpload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max for mobile photos
});
