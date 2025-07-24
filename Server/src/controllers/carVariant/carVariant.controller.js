import CarVariant from "../../models/carVariant.js";
import Provider from "../../models/provider.js";
import Car from "../../models/car.js";

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

    // Validate required fields
    if (!provider || !car || !color || !registrationNumber || !rentalPricePerDay || !depositAmount) {
      return res.status(400).json({ message: "All required fields must be filled" });
    }

    // Check if provider exists
    const existingProvider = await Provider.findById(provider);
    if (!existingProvider) {
      return res.status(404).json({ message: "Provider not found" });
    }

    // Check if car exists
    const existingCar = await Car.findById(car);
    if (!existingCar) {
      return res.status(404).json({ message: "Car not found" });
    }

    // Check if registration number is unique
    const existingVariant = await CarVariant.findOne({ registrationNumber });
    if (existingVariant) {
      return res.status(400).json({ message: "Car with this registration number already exists" });
    }

    // Create new car variant
    const newCarVariant = new CarVariant({
      provider,
      car,
      color,
      registrationNumber,
      rentalPricePerDay,
      depositAmount,
      insuranceDetails,
      images,
    });

    // Save to database
    await newCarVariant.save();

    res.status(201).json({
      message: "Car variant created successfully",
      carVariant: newCarVariant,
    });
  } catch (error) {
    res.status(500).json({ message: "Internal Server Error", error: error.message });
  }
};



export const getAllCarsForProvider = async (req, res) => {
    try {
      const { providerId } = req.params;  // Get providerId from request params
      const { model } = req.query; // Optional model filter from query parameters
  
      // Find cars for the given provider
      let query = { provider: providerId };
      if (model) {
        // If model is provided, add model filter
        query.model = model;
      }
  
      const cars = await CarVariant.find(query);  // Find all cars matching the query
  
      if (cars.length === 0) {
        return res.status(404).json({ message: "No cars found for this provider" });
      }
  
      return res.status(200).json(cars);
    } catch (error) {
      console.error(error);
      return res.status(500).json({ message: "Server Error" });
    }
  };

  export const getCarVariantsByCarId = async (req, res) => {
    try {
      const {carId} = req.params;

      const car = await Car.findById(carId);
      if (!car) {
        return res.status(404).json({ message: "Car model not found" });
      }

      const carVariants = await CarVariant.find({ car: carId });
      res.status(200).json(carVariants);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }