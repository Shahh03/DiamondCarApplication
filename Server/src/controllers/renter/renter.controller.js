import Renter from "../../models/renter.js";
import Booking from "../../models/booking.js";

export const getAllRenters = async (req, res) => {
    try {
      // Fetch all renters from the database
      const renters = await Renter.find();
  
      // If no renters found, return a message
      if (renters.length === 0) {
        return res.status(404).json({ message: "No renters found" });
      }
  
      // Send the renters data in the response
      res.status(200).json(renters);
    } catch (error) {
      // Handle any errors
      res.status(500).json({ message: error.message });
    }
  };

  export const getRenterbyId = async (req, res) => {
    try {
      const {renterId} = req.params;
      const renter = await Renter.findById(renterId);
  
      if (!renter) {
        return res.status(404).json({ message: "Renter not found" });
      }
  
      res.status(200).json(renter);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  };

  export const getBookingsForRenter = async (req, res) => {
    try {
        const { renterId } = req.params; 

        const bookings = await Booking.find({ renter: renterId })
    .populate({
        path: 'carVariant',
        populate: {
            path: 'car',
        },
    })
    .populate('payment');


        res.status(200).json(bookings);  
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

export const updateRenter = async (req, res) => {
  try {
    const { renterId } = req.params;
    const {
      name,
      nationality,
      occupation,
      location,
      gender,
      birthDate,
    } = req.body;

    // 🔎 Validate inputs
    if (!name || name.length < 2) {
      return res.status(400).json({ message: 'Name must be at least 2 characters' });
    }


    // 🧠 Build update object
    const updateFields = {
      name,
      nationality,
      occupation,
      location,
      gender,
      birthDate,
    };

    // 🛠️ Update renter
    const updatedRenter = await Renter.findByIdAndUpdate(renterId, updateFields, { new: true });

    if (!updatedRenter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    res.status(200).json(updatedRenter);
  } catch (error) {
    console.error('Update error:', error);
    res.status(500).json({ message: error.message });
  }
};



export const updateRenterCurrency = async (req, res) => {
  try {
    const { renterId } = req.params;
    const { currency } = req.body;

    const updatedRenter = await Renter.findByIdAndUpdate(renterId, { currency }, { new: true });

    if (!updatedRenter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    res.status(200).json(updatedRenter);
  } catch (error) {
    console.error('Update error:', error);
    res.status(500).json({ message: error.message });
  }
}

export const changeRenterUsername = async (req, res) => {
  try {
    const { renterId } = req.params;
    let { username } = req.body;

    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }


         username = username.toLowerCase();


    // Validate: at least 4 different letters
    const letters = username.match(/[a-zA-Z]/g) || [];
    const uniqueLetters = new Set(letters.map(l => l.toLowerCase()));
    if (uniqueLetters.size < 4) {
      return res.status(400).json({ message: 'Username must contain at least 4 different letters' });
    }

    // Check if renter exists
    const renter = await Renter.findById(renterId);
    if (!renter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    if (renter.username.toLowerCase() === username) {
      return res.status(400).json({ message: `${username} is already your username` });
    }
    const usernameTaken = await Renter.findOne({ username });
    if (usernameTaken) {
      return res.status(400).json({ message: 'Username already exists' });
    }

    renter.username = username;
    await renter.save();

    res.status(200).json(renter);
  } catch (error) {
    console.error('Update error:', error);
    res.status(500).json({ message: error.message });
  }
};


export const changeRenterPassword = async (req, res) => {
  try {
    const renterId = req.params.renterId; 
    const {oldPassword, newPassword } = req.body;

    const renter = await Renter.findById(renterId);
    if (!renter) {
      return res.status(404).json({ message: 'Renter not found' });
    }


    if (oldPassword!==renter.password) {
      return res.status(400).json({ message: 'Old password is incorrect' });
    }

    if (oldPassword === newPassword) {
      return res.status(400).json({ message: 'New password cannot be the same as the old password' });
    }

    renter.password = newPassword;
    await renter.save();

    res.status(200).json({ message: 'Password updated successfully' });
  }catch (error) {
    console.error('Update error:', error);
    res.status(500).json({ message: error.message });
  }

}
   

export const getWishlistforRenter = async (req, res) => {
  try {
    const renterId = req.params.renterId;
    const Renter = await Renter.findOne({ renter: renterId });

    if (!Renter) {
      return res.status(404).json({ message: 'Renter does not exist' });
    }
    res.status(200).json(wishlist);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
}
