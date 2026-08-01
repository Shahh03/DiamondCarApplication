import User from "../../models/user.js";
import Renter from "../../models/renter.js";
import Provider from "../../models/provider.js";
import { type } from "os";
//import bcrypt from "bcrypt";

export const createUser = async (req, res) => {
    try {    
        let { username, email, password, type, ...otherFields } = req.body;

        username = username.toLowerCase();
        email = email.toLowerCase();


        // Check if username or email already exists
        const existingUser = await User.findOne({ $or: [{ username }] }) ||
                             await Renter.findOne({ $or: [{ username }] }) ||
                             await Provider.findOne({ $or: [{ username }] });

        if (existingUser) {
            return res.status(400).json({ message: "Username already exists" });
        }

        const existingEmail = await User.findOne({ $or: [{ email }] }) ||
                             await Renter.findOne({ $or: [{ email }] }) ||
                             await Provider.findOne({ $or: [{ email }] });

        if (existingEmail) {
            return res.status(400).json({ message: "Email already exists" });
        }

        // Hash password before saving
        //const hashedPassword = await bcrypt.hash(password, 10);

        let newUser;

        if (type === "Renter") {
            newUser = new Renter({ username, email, password: password, type, ...otherFields });
        } else if (type === "Provider") {
            newUser = new Provider({ username, email, password: password, type, ...otherFields });
        } else if (type === "Admin") {
            newUser = new User({ username, email, password: password, type });
        } else {
            return res.status(400).json({ message: "Invalid user type" });
        }

        await newUser.save();
        res.status(201).json({ message: `${type} created successfully`, user: newUser });

    } catch (error) {
        res.status(500).json({ message: error.message });
    }    
};



export const loginUser = async (req, res) => {
  try {
    const identifier = req.body.identifier?.trim();
    const password = req.body.password;

    if (!identifier || !password) {
      return res.status(400).json({
        message: "Username/email and password are required",
      });
    }

    const escapedIdentifier = identifier.replace(
      /[.*+?^${}()|[\]\\]/g,
      "\\$&"
    );

    const existingUser = await User.findOne({
      $or: [
        {
          username: {
            $regex: `^${escapedIdentifier}$`,
            $options: "i",
          },
        },
        {
          email: identifier.toLowerCase(),
        },
      ],
    });

    if (!existingUser) {
      return res.status(404).json({
        message: "User does not exist",
      });
    }

    if (password !== existingUser.password) {
      return res.status(401).json({
        message: "Invalid username/email or password",
      });
    }

    return res.status(200).json({
      message: "Login successful",
      user: existingUser,
    });
  } catch (error) {
    console.error("Login error:", error);

    return res.status(500).json({
      message: "Internal server error",
    });
  }
};


export const getUserById = async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId).select("-password");

    if (!user) {
      return res.status(404).json({ message: "user not found" });
    }

    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const getPendingProviders = async (req, res) => {
  try {
    const pendingProviders = await Provider.find({ status: "Pending" })
      .select("-password") // Exclude password from response
      .lean(); // Converts Mongoose document to plain JS object

    if (pendingProviders.length === 0) {
      return res.status(404).json({ message: "No pending providers found" });
    }

    res.status(200).json(pendingProviders);
  } catch (error) {
    res.status(500).json({ message: "Internal Server Error", error: error.message });
  }
};


// Accept Provider
export const acceptProvider = async (req, res) => {
  try {
    const { providerId } = req.params;

    const provider = await Provider.findByIdAndUpdate(
      providerId,
      { status: "Accepted" },
      { new: true }
    );

    if (!provider) {
      return res.status(404).json({ message: "Provider not found" });
    }

    res.status(200).json({ message: "Provider accepted successfully", provider });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

// Reject Provider
export const rejectProvider = async (req, res) => {
  try {
    const { providerId } = req.params;

    const provider = await Provider.findByIdAndUpdate(
      providerId,
      { status: "Rejected" },
      { new: true }
    );

    if (!provider) {
      return res.status(404).json({ message: "Provider not found" });
    }

    res.status(200).json({ message: "Provider rejected successfully", provider });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};
