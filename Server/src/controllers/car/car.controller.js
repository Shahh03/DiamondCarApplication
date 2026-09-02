import Car from "../../models/car.js";

export const createCar = async (req, res) => {
  try {
    const {
      brand,
      model,
      year,
      category,
      transmission,
      fuelType,
      seats,
      features = [],
    } = req.body;

    if (!brand || !model || !year || !category || !transmission || !fuelType || !seats) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const existingCar = await Car.findOne({
      brand,
      model,
      year,
      category,
      transmission,
      fuelType,
      seats,
      features: { $all: Array.isArray(features) ? features : [] },
    });
    if (existingCar) {
      return res.status(409).json({
        message: "A car with the same specifications already exists",
      });
    }

    const car = await Car.create({
      brand,
      model,
      year,
      category,
      transmission,
      fuelType,
      seats,
      features: Array.isArray(features) ? features : [],
    });

    return res.status(201).json({ message: "Car created successfully", car });
  } catch (error) {
    console.error("Create car error:", error);
    return res.status(500).json({ message: "Could not create car" });
  }
};

export const getAllCars = async (_req, res) => {
  try {
    const cars = await Car.find()
      .sort({ brand: 1, model: 1, year: -1 })
      .lean();
    return res.status(200).json(cars);
  } catch (error) {
    console.error("Get cars error:", error);
    return res.status(500).json({ message: "Could not load car models" });
  }
};
