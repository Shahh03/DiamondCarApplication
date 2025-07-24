import Payment from "../../models/payment.js";
import Booking from "../../models/booking.js";
import Renter from "../../models/renter.js";
import Provider from "../../models/provider.js";
import CarVariant from "../../models/carVariant.js";

export const createPaymentAndBooking = async (req, res) => {
    const { renter, provider, paymentMethod, carVariant, startDate, endDate } = req.body;

    // Validate required fields
    if (!renter || !provider || !paymentMethod || !carVariant || !startDate || !endDate) {
        return res.status(400).json({ message: "All required fields must be filled" });
    }

    // Check if renter exists
    const existingRenter = await Renter.findById(renter);
    if (!existingRenter) {
        return res.status(404).json({ message: "Renter not found" });
    }

    // Check if provider exists
    const existingProvider = await Provider.findById(provider);
    if (!existingProvider) {
        return res.status(404).json({ message: "Provider not found" });
    }

    // Check if carVariant exists
    const existingCarVariant = await CarVariant.findById(carVariant);
    if (!existingCarVariant) {
        return res.status(404).json({ message: "Car variant not found" });
    }

    // Check if car is available
    if (!existingCarVariant.isAvailable) {
        return res.status(400).json({ message: "Car is not available" });
    }

    // Calculate total price
    const days = Math.ceil((new Date(endDate) - new Date(startDate)) / (1000 * 60 * 60 * 24));
    const totalPrice = days * existingCarVariant.rentalPricePerDay;
    const amount = totalPrice;

    // Create payment
    const payment = new Payment({
        renter,
        provider,
        amount,
        paymentMethod,
    });
    await payment.save();

    existingCarVariant.isAvailable = false;
    await existingCarVariant.save();


    // Create booking
    const booking = new Booking({
        renter,
        carVariant,
        startDate,
        endDate,
        totalPrice,
        payment: payment._id
    });
    await booking.save();

    // Mark car variant as unavailable

    res.status(201).json({
        message: "Payment and booking created successfully",
        payment,
        booking,
    });
};

export const refundPayment = async (req, res) => {
    const { paymentId } = req.params;

    try {
        // Find payment
        const payment = await Payment.findById(paymentId);
        if (!payment) {  
            return res.status(404).json({ message: "Payment not found" });
        }

        // Find booking associated with the payment
        const booking = await Booking.findOne({ payment: paymentId });

        if (!booking) {
            return res.status(404).json({ message: "Booking for payment not found" });
        }

        // Check if booking is cancelled
        if (booking.status !== "Cancelled") {
            return res.status(400).json({ message: "Cannot refund a booking that has not been cancelled" });
        }

        // Check if already refunded
        if (payment.paymentStatus === "Refunded") {
            return res.status(400).json({ message: "Payment is already refunded" });
        }

        // Update payment status
        payment.paymentStatus = "Refunded";
        payment.refundDetails = {
            refundedAmount: payment.amount,
            refundDate: new Date(),
            reason: "Booking Cancelled",
        };

        await payment.save();

        res.status(200).json({ message: "Payment refunded successfully", payment });

    } catch (error) {    
        res.status(500).json({ message: "Server error", error: error.message });
    }
};

