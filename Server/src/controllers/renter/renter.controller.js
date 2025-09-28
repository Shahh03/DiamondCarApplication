import Renter from "../../models/renter.js";
import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";
import mongoose from 'mongoose';


import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";



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

    // Find renter and populate wishlist and car details
    const renter = await Renter.findOne({ _id: renterId })
      .populate({
        path: 'wishlist',
        populate: { path: 'car' } // this ensures car details are included
      });

    if (!renter) {
      return res.status(404).json({ message: 'Renter does not exist' });
    }

    // Return wishlist array directly
    res.status(200).json(renter.wishlist);
  } catch (error) {
    console.error("Error fetching wishlist:", error);
    res.status(500).json({ message: error.message });
  }
};

export const removeFromWishlist = async (req, res) => {
  const { renterId, carVariantId } = req.params;

  try {
    const renter = await Renter.findById(renterId);
    if (!renter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    // Optional: Validate carVariant exists
    const carVariant = await CarVariant.findById(carVariantId);
    if (!carVariant) {
      return res.status(404).json({ message: 'Car variant not found' });
    }

    // Remove the car from wishlist
    renter.wishlist = renter.wishlist.filter(
      (id) => id.toString() !== carVariantId
    );

    await renter.save();
    res.status(200).json({ message: 'Car removed from wishlist', wishlist: renter.wishlist });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: error.message });
  }
};




const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

export const changeRenterProfilePicture = async (req, res) => {
  try {
    const { renterId } = req.params;

    // validate ObjectId to avoid CastError
    if (!mongoose.Types.ObjectId.isValid(renterId)) {
      if (req.file?.path) fs.unlink(req.file.path, () => {});
      return res.status(400).json({ error: 'Invalid renterId' });
    }

    // multer.single('file') must have populated req.file
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded (use form-data key "file")' });
    }

    const renter = await Renter.findById(renterId);
    if (!renter) {
      fs.unlink(req.file.path, () => {});
      return res.status(404).json({ error: 'Renter not found' });
    }

    // build a public relative path that starts with /uploads/...
    const normalized = (req.file.path || '').replace(/\\/g, '/');
    const i = normalized.lastIndexOf('/uploads/');
    const relPath = i !== -1
      ? normalized.substring(i)
      : `/uploads/renters/profile/${req.file.filename}`;

    // delete old local file if we own it
    const oldRel = renter.profilePicture?.filepath;
    if (oldRel && oldRel.startsWith('/uploads/')) {
      const oldAbs = path.join(__dirname, '..', '..', oldRel);
      fs.unlink(oldAbs, () => {});
    }

    renter.profilePicture = {
      filename: req.file.filename,  // stored filename on disk
      filepath: relPath,            // relative public URL
    };
    await renter.save();

    return res.json({
      message: 'Profile picture updated',
      renter: {
        _id: renter._id,
        name: renter.name,
        profilePicture: renter.profilePicture,
      },
    });
  } catch (e) {
    console.error('changeRenterProfilePicture error:', e);
    return res.status(500).json({ error: 'Failed to change profile picture' });
  }
};

export const addToWishlist = async (req, res) => {
  try {
    const { renterId, carVariantId } = req.params;

    const renter = await Renter.findById(renterId);
    if (!renter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    const carVariant = await CarVariant.findById(carVariantId);
    if (!carVariant) {
      return res.status(404).json({ message: 'Car variant not found' });
    }

    if (renter.wishlist.includes(carVariantId)) {
      return res.status(400).json({ message: 'Car variant already in wishlist' });
    }

    renter.wishlist.push(carVariantId);
    await renter.save();

    res.status(200).json({ message: 'Car variant added to wishlist', wishlist: renter.wishlist });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: error.message });
  } 
}