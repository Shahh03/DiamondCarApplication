import e from "express";
import Review from "../../models/review.js";

export const createReview = async (req, res) => {
    try {
        const { renter, reviewType, provider, car, booking, rating, comment } = req.body;

        // Validation checks for required fields based on review type
        if (reviewType === "Provider" && !provider) {
            return res.status(400).json({ message: "Provider is required for a provider review" });
        }
        if (reviewType === "Car" && !car) {
            return res.status(400).json({ message: "Car is required for a car review" });
        }
        if (reviewType === "Booking" && !booking) {
            return res.status(400).json({ message: "Booking is required for a booking review" });
        }
        if (!renter || !rating || !comment) {
            return res.status(400).json({ message: "All required fields must be filled" });
        }

        // Create new review object
        const newReview = new Review({
            renter, 
            reviewType, 
            provider, 
            car, 
            booking, 
            rating, 
            comment
        });

        // Save the review to the database
        await newReview.save();

        // Send a success response with the created review data
        res.status(201).json({
            message: "Review created successfully",
            review: newReview
        });

    } catch (error) {
        // Handle any errors that occur during the process
        res.status(500).json({ message: error.message });
    }
};

export const getAllReviewsForCar = async (req, res) => {
    try {
        const { carId } = req.params;

        const reviews = await Review.find({ reviewType: "Car", car: carId});

        res.status(200).json(reviews);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

export const getAllReviewsForProvider = async (req, res) => {
    try {
        const { providerId } = req.params;

        const reviews = await Review.find({ reviewType: "Provider" ,provider: providerId });

        res.status(200).json(reviews);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

export const getAllReviewsForBooking = async (req, res) => {
    try {
        const { bookingId } = req.params;    

        const reviews = await Review.find({ reviewType: "Booking" ,  booking: bookingId });

        res.status(200).json(reviews);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

export const getAllReviewsForRenter = async (req, res) => {
    try {
        const { renterId } = req.params;

        const reviews = await Review.find({ renter: renterId});

        res.status(200).json(reviews);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
