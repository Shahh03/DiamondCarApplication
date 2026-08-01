import mongoose from "mongoose";

import Booking from "../models/booking.js";
import CarVariant from "../models/carVariant.js";
import Renter from "../models/renter.js";
import UserActivity from "../models/userActivity.js";

const ACTIVITY_WINDOW_DAYS = 90;
const ACTIVITY_HALF_LIFE_DAYS = 14;
const SAFE_PROVIDER_FIELDS =
  "companyName address.city address.country profilePicture isVerified status";

const normalize = (value) => value?.toString().trim().toLowerCase() ?? "";

const addWeight = (map, value, weight) => {
  const key = normalize(value);
  if (!key || !Number.isFinite(weight) || weight <= 0) return;
  map.set(key, (map.get(key) ?? 0) + weight);
};

const maximumWeight = (map) => {
  if (map.size === 0) return 0;
  return Math.max(...map.values());
};

const affinityPoints = (map, value, maximumPoints) => {
  const highest = maximumWeight(map);
  if (highest <= 0) return 0;
  return ((map.get(normalize(value)) ?? 0) / highest) * maximumPoints;
};

const daysSince = (date) => {
  const milliseconds = Date.now() - new Date(date).getTime();
  return Math.max(0, milliseconds / (1000 * 60 * 60 * 24));
};

const timeDecay = (date) =>
  Math.pow(0.5, daysSince(date) / ACTIVITY_HALF_LIFE_DAYS);

const numericPrice = (value) => {
  const price = Number(value);
  return Number.isFinite(price) && price >= 0 ? price : null;
};

const deterministicTieBreaker = (id) => {
  const text = id.toString();
  let hash = 0;
  for (const character of text) {
    hash = (hash * 31 + character.charCodeAt(0)) % 1000;
  }
  return hash / 1000;
};

const preferenceState = () => ({
  categories: new Map(),
  brands: new Map(),
  transmissions: new Map(),
  fuels: new Map(),
  queries: new Map(),
  priceTotal: 0,
  priceWeight: 0,
});

const addPrice = (preferences, value, weight) => {
  const price = numericPrice(value);
  if (price == null || weight <= 0) return;
  preferences.priceTotal += price * weight;
  preferences.priceWeight += weight;
};

const addCarPreferences = (preferences, variant, weight) => {
  const car = variant?.car;
  if (!car) return;

  addWeight(preferences.categories, car.category, weight);
  addWeight(preferences.brands, car.brand, weight);
  addWeight(preferences.transmissions, car.transmission, weight);
  addWeight(preferences.fuels, car.fuelType, weight);
  addPrice(preferences, variant.rentalPricePerDay, weight);
};

const queryMatchPoints = (queries, car, maximumPoints) => {
  const highest = maximumWeight(queries);
  if (highest <= 0) return 0;

  const searchable = normalize(`${car?.brand ?? ""} ${car?.model ?? ""}`);
  let bestWeight = 0;

  for (const [query, weight] of queries.entries()) {
    if (query.length >= 2 && searchable.includes(query)) {
      bestWeight = Math.max(bestWeight, weight);
    }
  }

  return (bestWeight / highest) * maximumPoints;
};

const pricePoints = (price, preferredPrice) => {
  const candidatePrice = numericPrice(price);
  if (candidatePrice == null) return 0;
  if (preferredPrice == null || preferredPrice <= 0) return 10;

  const percentageDifference =
    Math.abs(candidatePrice - preferredPrice) / preferredPrice;
  return Math.max(0, 20 * (1 - percentageDifference));
};

const bookingWeight = (status) => (status === "Completed" ? 5 : 4);

const buildPreferences = ({ renter, bookings, activities }) => {
  const preferences = preferenceState();

  for (const booking of bookings) {
    addCarPreferences(
      preferences,
      booking.carVariant,
      bookingWeight(booking.status)
    );
  }

  for (const variant of renter.wishlist ?? []) {
    addCarPreferences(preferences, variant, 4);
  }

  for (const activity of activities) {
    const decay = timeDecay(activity.createdAt);

    if (activity.eventType === "view" && activity.carVariant) {
      addCarPreferences(preferences, activity.carVariant, 2 * decay);
      continue;
    }

    const data = activity.searchData ?? {};
    const eventWeight = activity.eventType === "search" ? 2.5 : 1.5;
    const weight = eventWeight * decay;

    addWeight(preferences.categories, data.category, weight);
    addWeight(preferences.brands, data.brand, weight);
    addWeight(preferences.transmissions, data.transmission, weight);
    addWeight(preferences.fuels, data.fuelType, weight);
    addWeight(preferences.queries, data.query, weight);

    const minimum = numericPrice(data.minPrice);
    const maximum = numericPrice(data.maxPrice);
    if (minimum != null && maximum != null) {
      addPrice(preferences, (minimum + maximum) / 2, weight);
    } else {
      addPrice(preferences, maximum ?? minimum, weight);
    }
  }

  return preferences;
};

const reasonFor = ({
  car,
  provider,
  renterLocation,
  preferences,
  popularity,
}) => {
  if ((preferences.categories.get(normalize(car?.category)) ?? 0) > 0) {
    return `Matches your ${car.category} preference`;
  }
  if ((preferences.brands.get(normalize(car?.brand)) ?? 0) > 0) {
    return `Because you showed interest in ${car.brand}`;
  }
  if (
    renterLocation &&
    normalize(provider?.address?.city) === normalize(renterLocation)
  ) {
    return `Available in ${provider.address.city}`;
  }
  if (popularity > 0) return "Popular with renters";
  return "Available for your next trip";
};

const diversify = (rankedCars, limit) => {
  const selected = [];
  const deferred = [];
  const brandCounts = new Map();
  const categoryCounts = new Map();

  for (const candidate of rankedCars) {
    const brand = normalize(candidate.car?.brand);
    const category = normalize(candidate.car?.category);
    const brandCount = brandCounts.get(brand) ?? 0;
    const categoryCount = categoryCounts.get(category) ?? 0;

    if (brandCount >= 2 || categoryCount >= 3) {
      deferred.push(candidate);
      continue;
    }

    selected.push(candidate);
    brandCounts.set(brand, brandCount + 1);
    categoryCounts.set(category, categoryCount + 1);
    if (selected.length === limit) return selected;
  }

  for (const candidate of deferred) {
    selected.push(candidate);
    if (selected.length === limit) break;
  }

  return selected;
};

export const getRecommendationsForRenter = async (renterId, limit = 8) => {
  if (!mongoose.isValidObjectId(renterId)) {
    const error = new Error("Invalid renter ID");
    error.statusCode = 400;
    throw error;
  }

  const activityStart = new Date(
    Date.now() - ACTIVITY_WINDOW_DAYS * 24 * 60 * 60 * 1000
  );

  const [renter, bookings, activities, candidates] = await Promise.all([
    Renter.findById(renterId)
      .populate({
        path: "wishlist",
        populate: { path: "car" },
      })
      .lean(),
    Booking.find({ renter: renterId, status: { $ne: "Cancelled" } })
      .populate({
        path: "carVariant",
        populate: { path: "car" },
      })
      .lean(),
    UserActivity.find({
      renter: renterId,
      createdAt: { $gte: activityStart },
    })
      .sort({ createdAt: -1 })
      .limit(250)
      .populate({
        path: "carVariant",
        populate: { path: "car" },
      })
      .lean(),
    CarVariant.find({ isAvailable: true })
      .populate("car")
      .populate("provider", SAFE_PROVIDER_FIELDS)
      .lean(),
  ]);

  if (!renter) {
    const error = new Error("Renter not found");
    error.statusCode = 404;
    throw error;
  }

  if (candidates.length === 0) return [];

  const candidateIds = candidates.map((candidate) => candidate._id);
  const popularityRows = await Booking.aggregate([
    {
      $match: {
        carVariant: { $in: candidateIds },
        status: { $ne: "Cancelled" },
      },
    },
    { $group: { _id: "$carVariant", count: { $sum: 1 } } },
  ]);

  const popularityByVariant = new Map(
    popularityRows.map((row) => [row._id.toString(), row.count])
  );
  const highestPopularity = Math.max(
    1,
    ...popularityRows.map((row) => row.count)
  );
  const preferences = buildPreferences({ renter, bookings, activities });
  const preferredPrice =
    preferences.priceWeight > 0
      ? preferences.priceTotal / preferences.priceWeight
      : null;
  const renterLocation = renter.location;

  const ranked = candidates
    .filter((variant) => variant.car && variant.provider)
    .map((variant) => {
      const car = variant.car;
      const provider = variant.provider;
      const popularity = popularityByVariant.get(variant._id.toString()) ?? 0;
      const categoryScore = affinityPoints(
        preferences.categories,
        car.category,
        25
      );
      const brandScore = Math.max(
        affinityPoints(preferences.brands, car.brand, 15),
        queryMatchPoints(preferences.queries, car, 15)
      );
      const locationScore =
        renterLocation &&
        normalize(provider.address?.city) === normalize(renterLocation)
          ? 15
          : 0;
      const score =
        categoryScore +
        brandScore +
        pricePoints(variant.rentalPricePerDay, preferredPrice) +
        locationScore +
        affinityPoints(preferences.transmissions, car.transmission, 8) +
        affinityPoints(preferences.fuels, car.fuelType, 7) +
        (popularity / highestPopularity) * 10;

      return {
        ...variant,
        recommendationScore: Number(Math.min(100, score).toFixed(2)),
        recommendationReason: reasonFor({
          car,
          provider,
          renterLocation,
          preferences,
          popularity,
        }),
        _tieBreaker: deterministicTieBreaker(variant._id),
      };
    })
    .sort(
      (first, second) =>
        second.recommendationScore - first.recommendationScore ||
        second._tieBreaker - first._tieBreaker
    )
    .map(({ _tieBreaker, ...variant }) => variant);

  return diversify(ranked, limit);
};