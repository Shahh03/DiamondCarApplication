import mongoose from "mongoose";

import cloudinary from "../../config/cloudinary.js";
import Car from "../../models/car.js";
import CarVariant from "../../models/carVariant.js";
import Provider from "../../models/provider.js";
import { getRecommendationsForRenter } from "../../services/recommendation.service.js";
import { uploadBufferToCloudinary } from "../../utils/uploadToCloudinary.js";

const SAFE_PROVIDER_FIELDS =
  "companyName address.city address.country profilePicture isVerified status";
const PUBLIC_VARIANT_FIELDS =
  "provider car color rentalPricePerDay depositAmount isAvailable images";

const populatePublicCarData = (query) =>
  query
    .select(PUBLIC_VARIANT_FIELDS)
    .populate("provider", SAFE_PROVIDER_FIELDS)
    .populate("car");

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
      images,
    } = req.body;

    if (
      !provider ||
      !car ||
      !color ||
      !registrationNumber ||
      rentalPricePerDay == null ||
      depositAmount == null
    ) {
      return res.status(400).json({ message: "All required fields must be filled" });
    }
    if (!mongoose.isValidObjectId(provider) || !mongoose.isValidObjectId(car)) {
      return res.status(400).json({ message: "Invalid provider or car ID" });
    }

    const [existingProvider, existingCar, duplicate] = await Promise.all([
      Provider.findById(provider),
      Car.findById(car),
      CarVariant.findOne({ registrationNumber: registrationNumber.trim() }),
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
      color: color.trim(),
      registrationNumber: registrationNumber.trim(),
      rentalPricePerDay,
      depositAmount,
      insuranceDetails,
      images,
    });
    return res.status(201).json({
      message: "Car variant created successfully",
      carVariant: variant,
    });
  } catch (error) {
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

    const query = { provider: providerId };
    if (model) {
      const cars = await Car.find({ model: { $regex: model, $options: "i" } }).select("_id");
      query.car = { $in: cars.map((car) => car._id) };
    }

    const variants = await CarVariant.find(query).populate("car");
    return res.status(200).json(variants);
  } catch (error) {
    console.error("Get provider cars error:", error);
    return res.status(500).json({ message: "Server Error" });
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
      CarVariant.find({ car: carId, isAvailable: true })
    );
    return res.status(200).json(variants);
  } catch (error) {
    return res.status(500).json({ message: "Could not load car variants" });
  }
};

export const getAllAvaiableCarVariants = async (_req, res) => {
  try {
    const variants = await populatePublicCarData(
      CarVariant.find({ isAvailable: true })
    );
    return res.status(200).json(variants);
  } catch (error) {
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
      CarVariant.findById(carVariantId)
    );
    if (!variant) return res.status(404).json({ message: "Car variant not found" });
    return res.status(200).json(variant);
  } catch (error) {
    return res.status(500).json({ message: "Could not load car variant" });
  }
};

export const uploadCarVariantImages = async (req, res) => {
  let uploadedPublicIds = [];
  try {
    const { carVariantId } = req.params;
    if (!mongoose.isValidObjectId(carVariantId)) {
      return res.status(400).json({ message: "Invalid car variant ID" });
    }
    if (!req.files?.length) {
      return res.status(400).json({ message: "No images uploaded" });
    }

    const variant = await CarVariant.findById(carVariantId);
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
        uploadBufferToCloudinary(file.buffer, "car-rental/car-variants/images")
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
