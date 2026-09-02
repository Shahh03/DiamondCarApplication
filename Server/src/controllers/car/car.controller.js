import Car from "../../models/car.js";

export const createCar = async (req, res) => {
  try {
    const { brand, model, year, category, transmission, fuelType, seats, features } = req.body;

    // Validate required fields
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
      features: { $all: features },
    });
    if (existingCar) {
      return res.status(400).json({ message: "A car with the same features already exists" });
    }

    // Create a new car
    const newCar = new Car({
      brand,
      model,
      year,
      category,
      transmission,
      fuelType,
      seats,
      features,
    });

    // Save car to the database
    await newCar.save();

    res.status(201).json({
      message: "Car created successfully",
      car: newCar,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Internal Server Error", error: error.message });
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
    return res.status(500).json({
      message: "Could not load car models",
    });
  }
};
