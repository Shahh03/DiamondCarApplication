import mongoose from "mongoose";

import cloudinary from "../../config/cloudinary.js";
import Booking from "../../models/booking.js";
import Car from "../../models/car.js";
import CarVariant from "../../models/carVariant.js";
import Provider from "../../models/provider.js";
import { getRecommendationsForRenter } from "../../services/recommendation.service.js";
import {
  cloudinaryFolders,
  uploadBufferToCloudinary,
} from "../../utils/uploadToCloudinary.js";

const SAFE_PROVIDER_FIELDS =
  "companyName address.city address.country profilePicture isVerified status currency";
const PUBLIC_VARIANT_FIELDS =
  "provider car color rentalPricePerDay depositAmount isAvailable images";
const LISTED = { isListed: { $ne: false } };

const populatePublicCarData = (query) =>
  query
    .select(PUBLIC_VARIANT_FIELDS)
    .populate("provider", SAFE_PROVIDER_FIELDS)
    .populate("car");

const validNonNegativeNumber = (value) => {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : null;
};

const cleanOptionalText = (value) => {
  if (value == null) return undefined;
  const text = value.toString().trim();
  return text || undefined;
};

export const createCarVariant = async (req, res) => {
  try {
    const {
      provider,
      car,
      color,
      registrationNumber,
      rentalPricePerDay,
      depositAmount,
      insuranceDetails,
    } = req.body;

    const dailyRate = validNonNegativeNumber(rentalPricePerDay);
    const deposit = validNonNegativeNumber(depositAmount);

    if (
      !provider ||
      !car ||
      !color?.toString().trim() ||
      !registrationNumber?.toString().trim() ||
      dailyRate == null ||
      deposit == null
    ) {
      return res.status(400).json({ message: "All required fields must be filled" });
    }
    if (!mongoose.isValidObjectId(provider) || !mongoose.isValidObjectId(car)) {
      return res.status(400).json({ message: "Invalid provider or car ID" });
    }

    const normalizedRegistration = registrationNumber.toString().trim();
    const [existingProvider, existingCar, duplicate] = await Promise.all([
      Provider.findById(provider),
      Car.findById(car),
      CarVariant.findOne({ registrationNumber: normalizedRegistration }),
    ]);

    if (!existingProvider) return res.status(404).json({ message: "Provider not found" });
    if (!existingCar) return res.status(404).json({ message: "Car not found" });
    if (duplicate) {
      return res.status(409).json({
        message: "Car with this registration number already exists",
      });
    }

    const variant = await CarVariant.create({
      provider,
      car,
      color: color.toString().trim(),
      registrationNumber: normalizedRegistration,
      rentalPricePerDay: dailyRate,
      depositAmount: deposit,
      insuranceDetails,
    });

    await variant.populate("car");
    return res.status(201).json({
      message: "Car variant created successfully",
      carVariant: variant,
    });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(409).json({
        message: "Car with this registration number already exists",
      });
    }
    console.error("Create car variant error:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

export const getAllCarsForProvider = async (req, res) => {
  try {
    const { providerId } = req.params;
    const model = req.query.model?.toString().trim();

    if (!mongoose.isValidObjectId(providerId)) {
      return res.status(400).json({ message: "Invalid provider ID" });
    }

    const query = { provider: providerId, ...LISTED };
    if (model) {
      const cars = await Car.find({
        model: { $regex: model, $options: "i" },
      }).select("_id");
      query.car = { $in: cars.map((car) => car._id) };
    }

    const variants = await CarVariant.find(query)
      .populate("car")
      .sort({ createdAt: -1 });
    return res.status(200).json(variants);
  } catch (error) {
    console.error("Get provider cars error:", error);
    return res.status(500).json({ message: "Server Error" });
  }
};

export const updateCarVariant = async (req, res) => {
  try {
    const variant = await CarVariant.findOne({
      _id: req.params.carVariantId,
      ...LISTED,
    });
    if (!variant) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    const {
      color,
      registrationNumber,
      rentalPricePerDay,
      depositAmount,
      isAvailable,
      insuranceDetails,
    } = req.body;

    if (color != null) {
      const value = color.toString().trim();
      if (!value) return res.status(400).json({ message: "Color is required" });
      variant.color = value;
    }

    if (registrationNumber != null) {
      const value = registrationNumber.toString().trim();
      if (!value) {
        return res.status(400).json({ message: "Registration number is required" });
      }
      const duplicate = await CarVariant.exists({
        _id: { $ne: variant._id },
        registrationNumber: value,
      });
      if (duplicate) {
        return res.status(409).json({
          message: "Car with this registration number already exists",
        });
      }
      variant.registrationNumber = value;
    }

    if (rentalPricePerDay != null) {
      const value = validNonNegativeNumber(rentalPricePerDay);
      if (value == null) {
        return res.status(400).json({ message: "Daily price must be zero or greater" });
      }
      variant.rentalPricePerDay = value;
    }

    if (depositAmount != null) {
      const value = validNonNegativeNumber(depositAmount);
      if (value == null) {
        return res.status(400).json({ message: "Deposit must be zero or greater" });
      }
      variant.depositAmount = value;
    }

    if (typeof isAvailable === "boolean") {
      variant.isAvailable = isAvailable;
    }

    if (insuranceDetails && typeof insuranceDetails === "object") {
      const expiryValue = insuranceDetails.expiryDate;
      let expiryDate;
      if (expiryValue) {
        expiryDate = new Date(expiryValue);
        if (Number.isNaN(expiryDate.getTime())) {
          return res.status(400).json({ message: "Insurance expiry date is invalid" });
        }
      }

      variant.insuranceDetails = {
        insuranceCompany: cleanOptionalText(insuranceDetails.insuranceCompany),
        policyNumber: cleanOptionalText(insuranceDetails.policyNumber),
        expiryDate,
      };
    }

    await variant.save();
    await variant.populate("car");
    return res.status(200).json({
      message: "Car variant updated successfully",
      carVariant: variant,
    });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(409).json({
        message: "Car with this registration number already exists",
      });
    }
    console.error("Update car variant error:", error);
    return res.status(500).json({ message: "Could not update car variant" });
  }
};

export const uploadCarVariantImages = async (req, res) => {
  let uploadedPublicIds = [];
  try {
    const { carVariantId } = req.params;
    if (!req.files?.length) {
      return res.status(400).json({ message: "No images uploaded" });
    }

    const variant = await CarVariant.findOne({ _id: carVariantId, ...LISTED });
    if (!variant) return res.status(404).json({ message: "Car variant not found" });

    const oldImages = variant.images ?? [];
    const oldPublicIds = variant.imagePublicIds ?? [];
    if (oldImages.length + req.files.length > 10) {
      return res.status(400).json({
        message:
          `Maximum 10 images allowed. This car already has ${oldImages.length}, ` +
          `so you can upload ${10 - oldImages.length} more.`,
      });
    }

    const results = await Promise.all(
      req.files.map((file) =>
        uploadBufferToCloudinary(
          file.buffer,
          cloudinaryFolders.carVariantImages(carVariantId)
        )
      )
    );
    const urls = results.map((result) => result.secure_url);
    uploadedPublicIds = results.map((result) => result.public_id);

    variant.images = [...oldImages, ...urls];
    variant.imagePublicIds = [...oldPublicIds, ...uploadedPublicIds];
    await variant.save();

    return res.status(200).json({
      message: "Car variant images uploaded successfully",
      images: variant.images,
      imagePublicIds: variant.imagePublicIds,
      imageCount: variant.images.length,
      remainingSlots: 10 - variant.images.length,
    });
  } catch (error) {
    console.error("Upload car variant images error:", error);
    await Promise.allSettled(
      uploadedPublicIds.map((publicId) =>
        cloudinary.uploader.destroy(publicId, {
          resource_type: "image",
          invalidate: true,
        })
      )
    );
    return res.status(500).json({ message: "Failed to upload car variant images" });
  }
};

export const removeCarVariantImage = async (req, res) => {
  try {
    const { imageUrl, imagePublicId } = req.body;
    if (!imageUrl && !imagePublicId) {
      return res.status(400).json({ message: "An image must be selected" });
    }

    const variant = await CarVariant.findOne({
      _id: req.params.carVariantId,
      ...LISTED,
    });
    if (!variant) return res.status(404).json({ message: "Car variant not found" });

    let index = -1;
    if (imagePublicId) index = (variant.imagePublicIds ?? []).indexOf(imagePublicId);
    if (index < 0 && imageUrl) index = (variant.images ?? []).indexOf(imageUrl);
    if (index < 0) return res.status(404).json({ message: "Image not found" });

    const publicId = variant.imagePublicIds?.[index];
    variant.images.splice(index, 1);
    if (variant.imagePublicIds?.length > index) {
      variant.imagePublicIds.splice(index, 1);
    }
    await variant.save();

    if (publicId) {
      try {
        await cloudinary.uploader.destroy(publicId, {
          resource_type: "image",
          invalidate: true,
        });
      } catch (cloudinaryError) {
        console.error("Could not remove archived Cloudinary image:", cloudinaryError);
      }
    }

    return res.status(200).json({
      message: "Image removed successfully",
      images: variant.images,
      imagePublicIds: variant.imagePublicIds,
    });
  } catch (error) {
    console.error("Remove car variant image error:", error);
    return res.status(500).json({ message: "Could not remove image" });
  }
};

export const reorderCarVariantImages = async (req, res) => {
  try {
    const { carVariantId } = req.params;
    const { orderedImageUrls } = req.body;

    if (!Array.isArray(orderedImageUrls)) {
      return res.status(400).json({
        message: "orderedImageUrls must be an array",
      });
    }

    const variant = await CarVariant.findOne({
      _id: carVariantId,
      ...LISTED,
    });
    if (!variant) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    const currentImages = variant.images ?? [];
    const currentPublicIds = variant.imagePublicIds ?? [];

    if (orderedImageUrls.length !== currentImages.length) {
      return res.status(400).json({
        message: "The image order must include every current vehicle image",
      });
    }

    if (new Set(orderedImageUrls).size !== orderedImageUrls.length) {
      return res.status(400).json({
        message: "The image order cannot contain duplicate images",
      });
    }

    const imageIndexes = new Map(
      currentImages.map((imageUrl, index) => [imageUrl, index])
    );
    const containsUnknownImage = orderedImageUrls.some(
      (imageUrl) =>
        typeof imageUrl !== "string" || !imageIndexes.has(imageUrl)
    );
    if (containsUnknownImage) {
      return res.status(400).json({
        message: "The image order contains an image that is not on this vehicle",
      });
    }

    if (currentPublicIds.length !== currentImages.length) {
      return res.status(409).json({
        message: "Vehicle image metadata is out of sync and cannot be reordered",
      });
    }

    variant.images = [...orderedImageUrls];
    if (currentPublicIds.length === currentImages.length) {
      variant.imagePublicIds = orderedImageUrls.map(
        (imageUrl) => currentPublicIds[imageIndexes.get(imageUrl)]
      );
    }

    await variant.save();

    return res.status(200).json({
      message: "Vehicle image order updated successfully",
      images: variant.images,
      imagePublicIds: variant.imagePublicIds,
    });
  } catch (error) {
    console.error("Reorder car variant images error:", error);
    return res.status(500).json({
      message: "Could not update vehicle image order",
    });
  }
};

export const archiveCarVariant = async (req, res) => {
  try {
    const variant = await CarVariant.findOne({
      _id: req.params.carVariantId,
      ...LISTED,
    });
    if (!variant) return res.status(404).json({ message: "Car variant not found" });

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const blockingBooking = await Booking.exists({
      carVariant: variant._id,
      status: { $in: ["Confirmed", "InProgress"] },
      endDate: { $gte: today },
    });
    if (blockingBooking) {
      return res.status(409).json({
        message: "This vehicle has an active or upcoming booking and cannot be removed",
      });
    }

    variant.isAvailable = false;
    variant.isListed = false;
    variant.archivedAt = new Date();
    await variant.save();

    return res.status(200).json({ message: "Vehicle removed from your fleet" });
  } catch (error) {
    console.error("Archive car variant error:", error);
    return res.status(500).json({ message: "Could not remove vehicle" });
  }
};

export const getCarVariantsByCarId = async (req, res) => {
  try {
    const { carId } = req.params;
    if (!mongoose.isValidObjectId(carId)) {
      return res.status(400).json({ message: "Invalid car ID" });
    }
    if (!(await Car.exists({ _id: carId }))) {
      return res.status(404).json({ message: "Car model not found" });
    }
    const variants = await populatePublicCarData(
      CarVariant.find({ car: carId, isAvailable: true, ...LISTED })
    );
    return res.status(200).json(variants);
  } catch {
    return res.status(500).json({ message: "Could not load car variants" });
  }
};

export const getAllAvaiableCarVariants = async (_req, res) => {
  try {
    const variants = await populatePublicCarData(
      CarVariant.find({ isAvailable: true, ...LISTED })
    );
    return res.status(200).json(variants);
  } catch {
    return res.status(500).json({ message: "Could not load available cars" });
  }
};

export const getRecommendedCarVariants = async (req, res) => {
  try {
    const requested = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(requested)
      ? Math.min(20, Math.max(1, requested))
      : 8;
    const recommendations = await getRecommendationsForRenter(
      req.params.renterId,
      limit
    );
    return res.status(200).json(recommendations);
  } catch (error) {
    console.error("Get recommendations error:", error);
    return res.status(error.statusCode ?? 500).json({
      message: error.message ?? "Failed to load recommendations",
    });
  }
};

export const getCarVariantByID = async (req, res) => {
  try {
    const { carVariantId } = req.params;
    if (!mongoose.isValidObjectId(carVariantId)) {
      return res.status(400).json({ message: "Invalid car variant ID" });
    }
    const variant = await populatePublicCarData(
      CarVariant.findOne({ _id: carVariantId, ...LISTED })
    );
    if (!variant) return res.status(404).json({ message: "Car variant not found" });
    return res.status(200).json(variant);
  } catch {
    return res.status(500).json({ message: "Could not load car variant" });
  }
};
