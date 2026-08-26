import Renter from "../../models/renter.js";
import Booking from "../../models/booking.js";
import CarVariant from "../../models/carVariant.js";
import User from "../../models/user.js";
import mongoose from "mongoose";

import cloudinary from "../../config/cloudinary.js";
import {cloudinaryFolders,uploadBufferToCloudinary,} from "../../utils/uploadToCloudinary.js";
import {
  hashPassword,
  isHashedPassword,
  verifyPassword,
} from "../../utils/password.js";
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
    const { username, password } = req.body;

    if (req.auth?.userId !== renterId) {
      return res.status(403).json({
        message: "You can only change your own username",
      });
    }

    if (!mongoose.isValidObjectId(renterId)) {
      return res.status(400).json({ message: "Invalid renter ID" });
    }

    if (typeof username !== "string" || typeof password !== "string") {
      return res.status(400).json({
        message: "Username and password are required",
      });
    }

    const newUsername = username.trim().toLowerCase();

    if (!/^[a-z0-9._-]{4,30}$/.test(newUsername)) {
      return res.status(400).json({
        message:
          "Username must be 4-30 characters and may only contain letters, numbers, dots, underscores, or hyphens",
      });
    }

    if (password.length === 0) {
      return res.status(400).json({ message: "Current password is required" });
    }

    const renter = await Renter.findById(renterId).select("+password");

    if (!renter) {
      return res.status(404).json({
        message: "Renter not found",
      });
    }

    if (renter.type !== "Renter") {
      return res.status(403).json({
        message: "Only renters can change their username",
      });
    }

    const passwordIsValid = await verifyPassword(password, renter.password);
    if (!passwordIsValid) {
      return res.status(401).json({
        message: "Current password is incorrect",
      });
    }

    if (newUsername === renter.username) {
      return res.status(400).json({
        message: "New username cannot be the same as current username",
      });
    }

    const existingUser = await User.exists({
      _id: { $ne: renterId },
      username: newUsername,
    });

    if (existingUser) {
      return res.status(409).json({
        message: "Username already taken",
      });
    }

    const cooldownDays = 30;

    if (renter.usernameLastChangedAt) {
      const daysSinceLastChange =
        (Date.now() - renter.usernameLastChangedAt.getTime()) /
        (1000 * 60 * 60 * 24);

      if (daysSinceLastChange < cooldownDays) {
        const daysLeft = Math.ceil(cooldownDays - daysSinceLastChange);

        return res.status(400).json({
          message: `You can change your username again in ${daysLeft} day(s)`,
        });
      }
    }

    renter.username = newUsername;
    renter.usernameLastChangedAt = new Date();
    renter.usernameChangeCount = (renter.usernameChangeCount || 0) + 1;

    // Upgrade a legacy plaintext password after successful verification.
    if (!isHashedPassword(renter.password)) {
      renter.password = await hashPassword(password);
    }

    await renter.save();

    return res.status(200).json({
      message: "Username updated successfully",
      username: renter.username,
    });
  } catch (error) {
    console.error("Change username error:", error);

    if (error?.code === 11000) {
      return res.status(409).json({ message: "Username already taken" });
    }

    return res.status(500).json({ message: "Could not update username" });
  }
};

export const changeRenterPassword = async (req, res) => {
  try {
    const { renterId } = req.params;
    const { oldPassword, newPassword } = req.body;

    if (req.auth?.userId !== renterId) {
      return res.status(403).json({
        message: "You can only change your own password",
      });
    }

    if (!mongoose.isValidObjectId(renterId)) {
      return res.status(400).json({ message: "Invalid renter ID" });
    }

    if (typeof oldPassword !== "string" || typeof newPassword !== "string") {
      return res.status(400).json({
        message: "Current password and new password are required",
      });
    }

    if (oldPassword.length === 0 || newPassword.length === 0) {
      return res.status(400).json({
        message: "Current password and new password are required",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        message: "New password must be at least 8 characters",
      });
    }

    // bcrypt only considers the first 72 UTF-8 bytes.
    if (Buffer.byteLength(newPassword, "utf8") > 72) {
      return res.status(400).json({
        message: "New password must not exceed 72 bytes",
      });
    }

    const renter = await Renter.findById(renterId).select(
      "+password +refreshTokens"
    );
    if (!renter) {
      return res.status(404).json({ message: "Renter not found" });
    }

    if (renter.type !== "Renter") {
      return res.status(403).json({
        message: "Only renters can change their password",
      });
    }

    const oldPasswordIsValid = await verifyPassword(
      oldPassword,
      renter.password
    );
    if (!oldPasswordIsValid) {
      return res.status(401).json({
        message: "Current password is incorrect",
      });
    }

    const passwordWasReused = await verifyPassword(
      newPassword,
      renter.password
    );
    if (passwordWasReused) {
      return res.status(400).json({
        message: "New password cannot be the same as the current password",
      });
    }

    renter.password = await hashPassword(newPassword);

    // Revoke every remembered session after a password change.
    renter.refreshTokens = [];
    await renter.save();

    return res.status(200).json({
      message: "Password updated successfully. Please sign in again.",
      requiresLogin: true,
    });
  } catch (error) {
    console.error("Change password error:", error);
    return res.status(500).json({ message: "Could not update password" });
  }
};
   

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



export const changeRenterProfilePicture = async (req, res) => {
  try {
    const { renterId } = req.params;

    if (!req.file) {
      return res.status(400).json({ message: 'No image uploaded' });
    }

    if (!req.file.buffer) {
      return res.status(400).json({ message: 'Uploaded file has no buffer' });
    }

    const renter = await Renter.findById(renterId);

    if (!renter) {
      return res.status(404).json({ message: 'Renter not found' });
    }

    const oldPublicId = renter.profilePicturePublicId;

    // 1. Upload new image from buffer to Cloudinary
    const uploadResult = await uploadBufferToCloudinary(
      req.file.buffer,
      cloudinaryFolders.renterProfile(renterId)
    );

    // 2. Save new Cloudinary URL and public_id
    renter.profilePicture = uploadResult.secure_url;
    renter.profilePicturePublicId = uploadResult.public_id;

    await renter.save();

    // 3. Delete old Cloudinary image after DB update succeeds
    if (oldPublicId) {
      try {
        await cloudinary.uploader.destroy(oldPublicId, {
          resource_type: 'image',
          invalidate: true,
        });
      } catch (deleteError) {
        console.error('Old profile picture delete failed:', deleteError);
      }
    }

    return res.status(200).json({
      message: 'Profile picture updated successfully',
      profilePicture: renter.profilePicture,
      profilePicturePublicId: renter.profilePicturePublicId,
    });

  } catch (error) {
    console.error('Change profile picture error:', error);

    return res.status(500).json({
      message: 'Failed to update profile picture',
      error: error.message,
    });
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

export const getUpcomingBookingsForRenter = async (req, res) => {
  try {
    const { renterId } = req.params;

    const bookings = await Booking.find({ renter: renterId, status: 'Confirmed' })
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
  
}

