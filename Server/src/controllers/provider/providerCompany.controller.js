import mongoose from "mongoose";
import Provider from "../../models/provider.js";
import cloudinary from "../../config/cloudinary.js";
import { cloudinaryFolders, uploadBufferToCloudinary } from "../../utils/uploadToCloudinary.js";

// Explicit projection: never send passwords, tokens, documents or bank details.
const fields = "_id companyName contactPerson address registrationNumber status isVerified profilePicture currency email username";
const validId = (req, res) => {
  if (mongoose.isValidObjectId(req.params.providerId)) return true;
  res.status(400).json({ message: "Invalid provider ID" });
  return false;
};
const failure = (res, error) => {
  console.error("Company profile error:", error.message);
  return res.status(500).json({ message: "Could not save company information. Please try again." });
};
export const getCompany = async (req, res) => {
  if (!validId(req, res)) return;
  try {
    const provider = await Provider.findById(req.params.providerId).select(fields).lean();
    if (!provider) return res.status(404).json({ message: "Provider not found" });
    return res.json(provider);
  } catch (error) {
    console.error("Get company error:", error.message);
    return res.status(500).json({ message: "Could not load company information. Please try again." });
  }
};

export const updateCompany = async (req, res) => {
  if (!validId(req, res)) return;
  const body = req.body;
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return res.status(400).json({ message: "Invalid company information" });
  }
  const allowed = ["companyName", "contactPerson", "address"];
  if (Object.keys(body).some((key) => !allowed.includes(key))) {
    return res.status(400).json({ message: "Only company name, contact details and address can be updated here." });
  }
  const definitions = [
    ["companyName", true, 150],
    ["contactPerson.name", true, 150],
    ["contactPerson.phoneNumber", true, 40],
    ["contactPerson.email", true, 254],
    ["address.street", false, 200],
    ["address.city", true, 100],
    ["address.state", false, 100],
    ["address.country", true, 100],
    ["address.postalCode", false, 30],
  ];
  const updates = {};
  for (const [key, required, max] of definitions) {
    const value = key.split(".").reduce((item, part) => item?.[part], body);
    if (typeof value !== "string" || (required && !value.trim()) || value.length > max) {
      return res.status(400).json({ message: `Please enter a valid ${key.replace(".", " ")} (maximum ${max} characters).` });
    }
    updates[key] = value.trim();
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(updates["contactPerson.email"])) {
    return res.status(400).json({ message: "Enter a valid contact email address." });
  }
  try {
    const provider = await Provider.findByIdAndUpdate(req.params.providerId,
      { $set: updates }, { new: true, runValidators: true }).select(fields).lean();
    if (!provider) return res.status(404).json({ message: "Provider not found" });
    return res.json(provider);
  } catch (error) {
    return failure(res, error);
  }
};

export const uploadCompanyPhoto = async (req, res) => {
  if (!validId(req, res)) return;
  if (!req.file || !["image/jpeg", "image/png", "image/webp"].includes(req.file.mimetype)) {
    return res.status(400).json({ message: "Choose a JPG, PNG or WebP image smaller than 10 MB." });
  }
  let uploaded;
  let committed = false;
  const removeAsset = async (id) => {
    try { await cloudinary.uploader.destroy(id); }
    catch (error) { console.error("Company photo cleanup failed:", error.message); }
  };
  try {
    const existing = await Provider.findById(req.params.providerId)
      .select("profilePicture +profilePicturePublicId").lean();
    if (!existing) return res.status(404).json({ message: "Provider not found" });
    uploaded = await uploadBufferToCloudinary(req.file.buffer, cloudinaryFolders.providerProfile(existing._id));
    // Compare the previous photo to prevent simultaneous uploads deleting the winning photo.
    const provider = await Provider.findOneAndUpdate({
      _id: existing._id,
      profilePicture: existing.profilePicture ?? { $in: ["", null] },
    }, { $set: { profilePicture: uploaded.secure_url, profilePicturePublicId: uploaded.public_id } },
    { new: true, runValidators: true }).select(fields).lean();
    if (!provider) {
      await removeAsset(uploaded.public_id);
      return res.status(409).json({ message: "The company photo changed. Refresh the page and try again." });
    }
    committed = true;
    if (existing.profilePicturePublicId) await removeAsset(existing.profilePicturePublicId);
    return res.json(provider);
  } catch (error) {
    if (uploaded && !committed) await removeAsset(uploaded.public_id);
    return failure(res, error);
  }
};
