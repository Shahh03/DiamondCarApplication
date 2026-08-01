import mongoose from "mongoose";

import cloudinary from "../../config/cloudinary.js";
import Car from "../../models/car.js";
import CarVariant from "../../models/carVariant.js";
import Provider from "../../models/provider.js";
import { getRecommendationsForRenter } from "../../services/recommendation.service.js";
import { uploadBufferToCloudinary } from "../../utils/uploadToCloudinary.js";

const SAFE_PROVIDER_FIELDS =
  "companyName address.city address.country profilePicture isVerified status";

const populatePublicCarData = (query) =>
  query
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
      return res.status(400).json({
        message: "All required fields must be filled",
      });
    }

    if (
      !mongoose.isValidObjectId(provider) ||
      !mongoose.isValidObjectId(car)
    ) {
      return res.status(400).json({ message: "Invalid provider or car ID" });
    }

    const [existingProvider, existingCar, existingVariant] = await Promise.all([
      Provider.findById(provider),
      Car.findById(car),
      CarVariant.findOne({ registrationNumber: registrationNumber.trim() }),
    ]);

    if (!existingProvider) {
      return res.status(404).json({ message: "Provider not found" });
    }
    if (!existingCar) {
      return res.status(404).json({ message: "Car not found" });
    }
    if (existingVariant) {
      return res.status(409).json({
        message: "Car with this registration number already exists",
      });
    }

    const newCarVariant = await CarVariant.create({
      provider,
      car,
      color,
      registrationNumber,
      rentalPricePerDay,
      depositAmount,
      insuranceDetails,
      images,
    });

    return res.status(201).json({
      message: "Car variant created successfully",
      carVariant: newCarVariant,
    });
  } catch (error) {
    console.error("Create car variant error:", error);
    return res.status(500).json({
      message: "Internal Server Error",
      error: error.message,
    });
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
      const matchingCars = await Car.find({
        model: { $regex: model, $options: "i" },
      }).select("_id");
      query.car = { $in: matchingCars.map((car) => car._id) };
    }

    const cars = await CarVariant.find(query).populate("car");
    return res.status(200).json(cars);
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

    const car = await Car.findById(carId);
    if (!car) {
      return res.status(404).json({ message: "Car model not found" });
    }

    const carVariants = await CarVariant.find({ car: carId }).populate(
      "provider",
      SAFE_PROVIDER_FIELDS
    );
    return res.status(200).json(carVariants);
  } catch (error) {
    console.error("Get variants by car error:", error);
    return res.status(500).json({ message: error.message });
  }
};

export const getAllAvaiableCarVariants = async (req, res) => {
  try {
    const carVariants = await CarVariant.find({
      isAvailable: true,
    })
      .populate("provider")
      .populate("car");

    return res.status(200).json(carVariants);
  } catch (error) {
    return res.status(500).json({
      message: error.message,getAllAvaiableCarVariants 
    });
  }
};

export const getRecommendedCarVariants = async (req, res) => {
  try {
    const requestedLimit = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(20, Math.max(1, requestedLimit))
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

    const carVariant = await populatePublicCarData(
      CarVariant.findById(carVariantId)
    );

    if (!carVariant) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    return res.status(200).json(carVariant);
  } catch (error) {
    console.error("Get car variant error:", error);
    return res.status(500).json({ message: error.message });
  }
};

export const uploadCarVariantImages = async (req, res) => {
  let uploadedPublicIds = [];

  try {
    const { carVariantId } = req.params;

    if (!mongoose.isValidObjectId(carVariantId)) {
      return res.status(400).json({ message: "Invalid car variant ID" });
    }
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ message: "No images uploaded" });
    }

    const carVariant = await CarVariant.findById(carVariantId);
    if (!carVariant) {
      return res.status(404).json({ message: "Car variant not found" });
    }

    const oldImages = carVariant.images ?? [];
    const oldPublicIds = carVariant.imagePublicIds ?? [];
    const totalImageCount = oldImages.length + req.files.length;

    if (totalImageCount > 10) {
      return res.status(400).json({
        message:
          `Maximum 10 images allowed. This car already has ` +
          `${oldImages.length}, so you can upload ${10 - oldImages.length} more.`,
      });
    }

    const uploadResults = await Promise.all(
      req.files.map((file) =>
        uploadBufferToCloudinary(
          file.buffer,
          "car-rental/car-variants/images"
        )
      )
    );
    const newImageUrls = uploadResults.map((result) => result.secure_url);
    const newPublicIds = uploadResults.map((result) => result.public_id);
    uploadedPublicIds = newPublicIds;

    carVariant.images = [...oldImages, ...newImageUrls];
    carVariant.imagePublicIds = [...oldPublicIds, ...newPublicIds];
    await carVariant.save();

    return res.status(200).json({
      message: "Car variant images uploaded successfully",
      images: carVariant.images,
      imagePublicIds: carVariant.imagePublicIds,
      imageCount: carVariant.images.length,
      remainingSlots: 10 - carVariant.images.length,
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

    return res.status(500).json({
      message: "Failed to upload car variant images",
      error: error.message,
    });
  }
};