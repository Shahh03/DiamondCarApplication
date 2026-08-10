import mongoose from "mongoose";

import CarVariant from "../../models/carVariant.js";
import Renter from "../../models/renter.js";
import UserActivity from "../../models/userActivity.js";

const ALLOWED_EVENT_TYPES = new Set(["view", "search", "filter"]);
const SEARCH_FIELDS = [
  "query",
  "brand",
  "category",
  "transmission",
  "fuelType",
  "minPrice",
  "maxPrice",
  "seats",
];

const cleanSearchData = (value) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;

  const cleaned = {};
  for (const field of SEARCH_FIELDS) {
    const fieldValue = value[field];
    if (typeof fieldValue === "string" && fieldValue.trim()) {
      cleaned[field] = fieldValue.trim();
    } else if (typeof fieldValue === "number" && Number.isFinite(fieldValue)) {
      cleaned[field] = fieldValue;
    }
  }

  return Object.keys(cleaned).length > 0 ? cleaned : null;
};

const requestedLimit = (rawValue, fallback = 10) => {
  const parsed = Number.parseInt(rawValue, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, 1), 20);
};

export const trackUserActivity = async (req, res) => {
  try {
    const { renterId, eventType, carVariantId } = req.body;
    const searchData = cleanSearchData(req.body.searchData);

    if (!mongoose.isValidObjectId(renterId)) {
      return res.status(400).json({ message: "Invalid renter ID" });
    }

    if (!ALLOWED_EVENT_TYPES.has(eventType)) {
      return res.status(400).json({
        message: "eventType must be view, search, or filter",
      });
    }

    const renterExists = await Renter.exists({ _id: renterId });
    if (!renterExists) {
      return res.status(404).json({ message: "Renter not found" });
    }

    if (eventType === "view") {
      if (!mongoose.isValidObjectId(carVariantId)) {
        return res.status(400).json({
          message: "A valid carVariantId is required for view events",
        });
      }

      const carExists = await CarVariant.exists({ _id: carVariantId });
      if (!carExists) {
        return res.status(404).json({ message: "Car variant not found" });
      }

      // Refreshing one recent record prevents rebuilds and repeated taps from
      // artificially dominating both recommendations and recent history.
      const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
      const recentView = await UserActivity.findOneAndUpdate(
        {
          renter: renterId,
          eventType: "view",
          carVariant: carVariantId,
          createdAt: { $gte: tenMinutesAgo },
        },
        { $set: { createdAt: new Date() } },
        { new: true, runValidators: true }
      );

      if (recentView) {
        return res.status(200).json({
          message: "View activity refreshed",
          activity: recentView,
        });
      }
    } else if (!searchData) {
      return res.status(400).json({
        message: "Search or filter activity must contain searchData",
      });
    }

    const activity = await UserActivity.create({
      renter: renterId,
      eventType,
      carVariant: eventType === "view" ? carVariantId : null,
      searchData: eventType === "view" ? undefined : searchData,
    });

    return res.status(201).json({
      message: "Activity recorded",
      activity,
    });
  } catch (error) {
    console.error("Track user activity error:", error);
    return res.status(500).json({
      message: "Failed to record activity",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};

export const getRecentlyViewedCarVariants = async (req, res) => {
  try {
    const { renterId } = req.params;

    if (!mongoose.isValidObjectId(renterId)) {
      return res.status(400).json({ message: "Invalid renter ID" });
    }

    const renterExists = await Renter.exists({ _id: renterId });
    if (!renterExists) {
      return res.status(404).json({ message: "Renter not found" });
    }

    const limit = requestedLimit(req.query.limit);

    // Read extra history so duplicates and cars that became unavailable do
    // not leave the response needlessly short.
    const activities = await UserActivity.find({
      renter: renterId,
      eventType: "view",
      carVariant: { $ne: null },
    })
      .sort({ createdAt: -1 })
      .limit(Math.min(limit * 10, 200))
      .select("carVariant createdAt")
      .lean();

    const orderedIds = [];
    const viewedAtById = new Map();

    for (const activity of activities) {
      const id = activity.carVariant?.toString();
      if (!id || viewedAtById.has(id)) continue;

      orderedIds.push(id);
      viewedAtById.set(id, activity.createdAt);
      if (orderedIds.length >= Math.min(limit * 5, 100)) break;
    }

    if (orderedIds.length === 0) {
      return res.status(200).json({ data: [] });
    }

    const variants = await CarVariant.find({
      _id: { $in: orderedIds },
      isAvailable: true,
    })
      .select(
        "provider car color rentalPricePerDay depositAmount isAvailable images createdAt updatedAt"
      )
      .populate({
        path: "car",
        select: "brand model year category transmission fuelType seats features",
      })
      .populate({
        path: "provider",
        select: "companyName address.city address.country profilePicture",
      })
      .lean();

    const variantById = new Map(
      variants.map((variant) => [variant._id.toString(), variant])
    );

    const data = orderedIds
      .map((id) => {
        const variant = variantById.get(id);
        if (!variant) return null;
        return {
          ...variant,
          viewedAt: viewedAtById.get(id),
        };
      })
      .filter(Boolean)
      .slice(0, limit);

    return res.status(200).json({ data });
  } catch (error) {
    console.error("Get recently viewed cars error:", error);
    return res.status(500).json({
      message: "Failed to load recently viewed cars",
      ...(process.env.NODE_ENV !== "production" && { error: error.message }),
    });
  }
};
