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

      // One view per car every ten minutes prevents repeated rebuilds or taps
      // from artificially dominating the recommendation history.
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
      error: error.message,
    });
  }
};