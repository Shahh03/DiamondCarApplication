import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";


export const cancelBooking = async (req, res) => {
try{
  const { bookingId } = req.params;

  // Find the booking by ID
  const booking = await Booking.findById(bookingId);

  if (!booking) {  
    return res.status(404).json({ message: "Booking not found" });
  }

  if(booking.status === "Cancelled"){
    return res.status(400).json({ message: "Booking is already cancelled" });
  }

  if(booking.endDate < new Date() || booking.status == "Completed"){  
    return res.status(400).json({ message: "Cannot cancel a booking that has already ended" });
  }

  if(booking.startDate < new Date()){
    return res.status(400).json({ message: "Cannot cancel a booking that has already started" });
  }

 
  booking.status = "Cancelled";
  await booking.save();

  const carVariant = await CarVariant.findById(booking.carVariant);
  carVariant.isAvailable = true;
  await carVariant.save();

  res.status(200).json({ message: "Booking cancelled successfully" });

} catch (error) {
  res.status(500).json({ message: "Internal Server Error", error: error.message });
}
}

export const getbookingbyId = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const booking = await Booking.findById(bookingId)
      .populate({
        path: 'carVariant',
        populate: [
          { path: 'car' },
          { path: 'provider' }
        ]
      })
      .populate("renter")
      .populate("payment");

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    res.status(200).json(booking);
  } catch (error) {
    res.status(500).json({ message: "Internal Server Error", error: error.message });
  }
};
