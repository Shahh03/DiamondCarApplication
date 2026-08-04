import crypto from "node:crypto";

import jwt from "jsonwebtoken";

import Provider from "../../models/provider.js";
import Renter from "../../models/renter.js";
import User from "../../models/user.js";
import {
  hashPassword,
  isHashedPassword,
  verifyPassword,
} from "../../utils/password.js";

const ACCESS_TOKEN_LIFETIME = "15m";
const REFRESH_TOKEN_DAYS = 90;
const MAX_SESSIONS = 5;

const requireJwtConfiguration = () => {
  if (!process.env.JWT_ACCESS_SECRET || !process.env.JWT_REFRESH_SECRET) {
    const error = new Error("JWT secrets are not configured");
    error.statusCode = 500;
    throw error;
  }
};

const hashToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const safeUser = (user) => {
  const value = user.toObject ? user.toObject() : { ...user };
  delete value.password;
  delete value.refreshTokens;
  return value;
};

const createAccessToken = (user) =>
  jwt.sign(
    { type: user.type },
    process.env.JWT_ACCESS_SECRET,
    { subject: user._id.toString(), expiresIn: ACCESS_TOKEN_LIFETIME }
  );

const createRefreshToken = (user) =>
  jwt.sign(
    { type: user.type, sessionId: crypto.randomUUID() },
    process.env.JWT_REFRESH_SECRET,
    { subject: user._id.toString(), expiresIn: `${REFRESH_TOKEN_DAYS}d` }
  );

const addRefreshToken = (user, refreshToken) => {
  const now = new Date();
  const expiresAt = new Date(
    Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000
  );

  const validSessions = (user.refreshTokens ?? [])
    .filter((item) => item.expiresAt > now)
    .slice(-(MAX_SESSIONS - 1));

  user.refreshTokens = [
    ...validSessions,
    { tokenHash: hashToken(refreshToken), expiresAt },
  ];
};

const issueSession = async (user) => {
  requireJwtConfiguration();

  const accessToken = createAccessToken(user);
  const refreshToken = createRefreshToken(user);
  addRefreshToken(user, refreshToken);
  await user.save();

  return { accessToken, refreshToken };
};

export const createUser = async (req, res) => {
  try {
    let { username, email, password, type, ...otherFields } = req.body;

    username = username?.trim().toLowerCase();
    email = email?.trim().toLowerCase();

    if (!username || !email || !password || !type) {
      return res.status(400).json({
        message: "Username, email, password and account type are required",
      });
    }

    const duplicate = await User.findOne({
      $or: [{ username }, { email }],
    }).select("username email");

    if (duplicate?.username === username) {
      return res.status(400).json({ message: "Username already exists" });
    }
    if (duplicate) {
      return res.status(400).json({ message: "Email already exists" });
    }

    const hashedPassword = await hashPassword(password);
    let newUser;

    if (type === "Renter") {
      newUser = new Renter({
        username,
        email,
        password: hashedPassword,
        type,
        ...otherFields,
      });
    } else if (type === "Provider") {
      newUser = new Provider({
        username,
        email,
        password: hashedPassword,
        type,
        ...otherFields,
      });
    } else if (type === "Admin") {
      newUser = new User({ username, email, password: hashedPassword, type });
    } else {
      return res.status(400).json({ message: "Invalid user type" });
    }

    await newUser.save();
    return res.status(201).json({
      message: `${type} created successfully`,
      user: safeUser(newUser),
    });
  } catch (error) {
    console.error("Create user error:", error);
    return res.status(500).json({ message: error.message });
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
        { username: { $regex: `^${escapedIdentifier}$`, $options: "i" } },
        { email: identifier.toLowerCase() },
      ],
    }).select("+password +refreshTokens");

    if (!existingUser) {
      return res.status(401).json({
        message: "Invalid username/email or password",
      });
    }

    const passwordIsValid = await verifyPassword(
      password,
      existingUser.password
    );

    if (!passwordIsValid) {
      return res.status(401).json({
        message: "Invalid username/email or password",
      });
    }

    // Transparently upgrade old plain-text records after a valid login.
    if (!isHashedPassword(existingUser.password)) {
      existingUser.password = await hashPassword(password);
    }

    const session = await issueSession(existingUser);

    return res.status(200).json({
      message: "Login successful",
      user: safeUser(existingUser),
      ...session,
    });
  } catch (error) {
    console.error("Login error:", error);
    return res.status(error.statusCode || 500).json({
      message: error.statusCode ? error.message : "Internal server error",
    });
  }
};

export const refreshSession = async (req, res) => {
  try {
    requireJwtConfiguration();
    const refreshToken = req.body.refreshToken;

    if (!refreshToken) {
      return res.status(401).json({ message: "Refresh token is required" });
    }

    const payload = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET
    );

    const user = await User.findById(payload.sub).select("+refreshTokens");
    if (!user) {
      return res.status(401).json({ message: "Session is no longer valid" });
    }

    const tokenHash = hashToken(refreshToken);
    const now = new Date();
    const storedSession = (user.refreshTokens ?? []).find(
      (item) => item.tokenHash === tokenHash && item.expiresAt > now
    );

    if (!storedSession) {
      return res.status(401).json({ message: "Session is no longer valid" });
    }

    // Rotate refresh tokens so a copied old token cannot be reused.
    user.refreshTokens = user.refreshTokens.filter(
      (item) => item.tokenHash !== tokenHash && item.expiresAt > now
    );

    const session = await issueSession(user);

    return res.status(200).json({
      user: safeUser(user),
      ...session,
    });
  } catch (error) {
    const invalidToken =
      error.name === "JsonWebTokenError" || error.name === "TokenExpiredError";

    return res.status(invalidToken ? 401 : error.statusCode || 500).json({
      message: invalidToken
        ? "Session has expired. Please log in again."
        : error.statusCode
          ? error.message
          : "Could not refresh session",
    });
  }
};

export const logoutUser = async (req, res) => {
  try {
    const refreshToken = req.body.refreshToken;
    if (refreshToken) {
      await User.updateOne(
        { "refreshTokens.tokenHash": hashToken(refreshToken) },
        {
          $pull: {
            refreshTokens: { tokenHash: hashToken(refreshToken) },
          },
        }
      );
    }

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (error) {
    console.error("Logout error:", error);
    return res.status(500).json({ message: "Could not log out" });
  }
};

export const getCurrentSession = async (req, res) => {
  try {
    const user = await User.findById(req.auth.userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    return res.status(200).json({ user: safeUser(user) });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

export const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    return res.status(200).json(user);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

export const getPendingProviders = async (_req, res) => {
  try {
    const pendingProviders = await Provider.find({ status: "Pending" }).lean();
    return res.status(200).json(pendingProviders);
  } catch (error) {
    return res.status(500).json({
      message: "Internal Server Error",
      error: error.message,
    });
  }
};

export const acceptProvider = async (req, res) => {
  try {
    const provider = await Provider.findByIdAndUpdate(
      req.params.providerId,
      { status: "Accepted" },
      { new: true }
    );
    if (!provider) return res.status(404).json({ message: "Provider not found" });
    return res.status(200).json({
      message: "Provider accepted successfully",
      provider,
    });
  } catch (error) {
    return res.status(500).json({ message: "Server error", error: error.message });
  }
};

export const rejectProvider = async (req, res) => {
  try {
    const provider = await Provider.findByIdAndUpdate(
      req.params.providerId,
      { status: "Rejected" },
      { new: true }
    );
    if (!provider) return res.status(404).json({ message: "Provider not found" });
    return res.status(200).json({
      message: "Provider rejected successfully",
      provider,
    });
  } catch (error) {
    return res.status(500).json({ message: "Server error", error: error.message });
  }
};
