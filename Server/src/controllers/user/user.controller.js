import crypto from "node:crypto";

import jwt from "jsonwebtoken";

import Provider from "../../models/provider.js";
import Renter from "../../models/renter.js";
import User from "../../models/user.js";
import { notifyProviderReviewed } from "../../services/notification.service.js";
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

const withoutSecrets = (user) => {
  const value = user.toObject ? user.toObject() : { ...user };
  delete value.password;
  delete value.refreshTokens;
  return value;
};

// Login and refresh only return fields needed to route into the application.
// The authenticated /user/session endpoint returns the full self profile.
const sessionUser = (user) => ({
  _id: user._id,
  username: user.username,
  email: user.email,
  type: user.type,
  hasAcceptedTerms: user.hasAcceptedTerms,
  ...(user.name != null && { name: user.name }),
  ...(user.companyName != null && { companyName: user.companyName }),
  ...(user.currency != null && { currency: user.currency }),
  ...(user.profilePicture != null && {
    profilePicture: user.profilePicture,
  }),
  ...(user.status != null && { status: user.status }),
  ...(user.isVerified != null && { isVerified: user.isVerified }),
});

const createAccessToken = (user) =>
  jwt.sign({ type: user.type }, process.env.JWT_ACCESS_SECRET, {
    algorithm: "HS256",
    subject: user._id.toString(),
    expiresIn: ACCESS_TOKEN_LIFETIME,
  });

const createRefreshToken = (user) =>
  jwt.sign(
    { type: user.type, sessionId: crypto.randomUUID() },
    process.env.JWT_REFRESH_SECRET,
    {
      algorithm: "HS256",
      subject: user._id.toString(),
      expiresIn: `${REFRESH_TOKEN_DAYS}d`,
    }
  );

const addRefreshToken = (user, refreshToken) => {
  const now = new Date();
  const expiresAt = new Date(
    Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000
  );

  const validSessions = (user.refreshTokens ?? [])
    .filter((item) => item.expiresAt > now)
    .sort((a, b) => a.createdAt - b.createdAt)
    .slice(-(MAX_SESSIONS - 1));

  user.refreshTokens = [
    ...validSessions,
    { tokenHash: hashToken(refreshToken), expiresAt, createdAt: now },
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

const pickDefined = (source, fields) =>
  Object.fromEntries(
    fields
      .filter((field) => source[field] !== undefined)
      .map((field) => [field, source[field]])
  );

const renterSignupFields = [
  "hasAcceptedTerms",
  "phoneNumber",
  "name",
  "nationality",
  "birthDate",
  "occupation",
  "gender",
  "drivingLicenseNumber",
  "idCardNumber",
  "location",
  "driverLicensePicture",
  "idPicture",
  "currency",
];

const providerSignupFields = [
  "hasAcceptedTerms",
  "companyName",
  "contactPerson",
  "address",
  "registrationNumber",
  "verificationDocuments",
  "bankDetails",
];

export const createUser = async (req, res) => {
  try {
    let { username, email, password, type } = req.body;
    username = username?.trim().toLowerCase();
    email = email?.trim().toLowerCase();

    if (!username || !email || !password || !type) {
      return res.status(400).json({
        message: "Username, email, password and account type are required",
      });
    }
    if (password.length < 8 || Buffer.byteLength(password, "utf8") > 72) {
      return res.status(400).json({
        message: "Password must be between 8 characters and 72 bytes",
      });
    }
    if (!new Set(["Renter", "Provider"]).has(type)) {
      return res.status(400).json({ message: "Invalid public account type" });
    }

    const duplicate = await User.findOne({
      $or: [{ username }, { email }],
    }).select("username email");

    if (duplicate?.username === username) {
      return res.status(409).json({ message: "Username already exists" });
    }
    if (duplicate) {
      return res.status(409).json({ message: "Email already exists" });
    }

    const base = {
      username,
      email,
      password: await hashPassword(password),
      type,
    };
    const newUser =
      type === "Renter"
        ? new Renter({
            ...base,
            ...pickDefined(req.body, renterSignupFields),
          })
        : new Provider({
            ...base,
            ...pickDefined(req.body, providerSignupFields),
          });

    await newUser.save();
    return res.status(201).json({
      message: `${type} created successfully`,
      user: sessionUser(newUser),
    });
  } catch (error) {
    console.error("Create user error:", error);
    if (error?.code === 11000) {
      return res.status(409).json({ message: "Account already exists" });
    }
    return res.status(500).json({ message: "Could not create account" });
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
    if (!(await verifyPassword(password, existingUser.password))) {
      return res.status(401).json({
        message: "Invalid username/email or password",
      });
    }

    if (!isHashedPassword(existingUser.password)) {
      existingUser.password = await hashPassword(password);
    }

    const session = await issueSession(existingUser);
    return res.status(200).json({
      message: "Login successful",
      user: sessionUser(existingUser),
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

    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET, {
      algorithms: ["HS256"],
    });
    if (typeof payload !== "object" || typeof payload.sub !== "string") {
      return res.status(401).json({ message: "Session is no longer valid" });
    }

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

    user.refreshTokens = user.refreshTokens.filter(
      (item) => item.tokenHash !== tokenHash && item.expiresAt > now
    );
    const session = await issueSession(user);

    return res.status(200).json({
      user: sessionUser(user),
      ...session,
    });
  } catch (error) {
    const invalid =
      error?.name === "JsonWebTokenError" ||
      error?.name === "TokenExpiredError";
    return res.status(invalid ? 401 : error.statusCode || 500).json({
      message: invalid
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
    if (!refreshToken) {
      return res.status(400).json({ message: "Refresh token is required" });
    }

    await User.updateOne(
      { "refreshTokens.tokenHash": hashToken(refreshToken) },
      { $pull: { refreshTokens: { tokenHash: hashToken(refreshToken) } } }
    );

    // Keep logout idempotent and do not reveal whether a token existed.
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
    return res.status(200).json({ user: withoutSecrets(user) });
  } catch (error) {
    return res.status(500).json({ message: "Could not load account" });
  }
};

export const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    return res.status(200).json(withoutSecrets(user));
  } catch (error) {
    return res.status(500).json({ message: "Could not load account" });
  }
};

export const getPendingProviders = async (_req, res) => {
  try {
    const providers = await Provider.find({ status: "Pending" }).lean();
    return res.status(200).json(providers);
  } catch (error) {
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

export const acceptProvider = async (req, res) => {
  try {
    const provider = await Provider.findOneAndUpdate(
      { _id: req.params.providerId, status: "Pending" },
      { status: "Accepted" },
      { new: true, runValidators: true }
    );
    if (!provider) {
      const existing = await Provider.findById(req.params.providerId)
        .select("status")
        .lean();
      if (!existing) {
        return res.status(404).json({ message: "Provider not found" });
      }
      return res.status(409).json({
        message: `Provider application is already ${existing.status.toLowerCase()}`,
      });
    }
    await notifyProviderReviewed({ providerId: provider._id, decision: "Accepted" });
    return res.status(200).json({
      message: "Provider accepted successfully",
      provider: withoutSecrets(provider),
    });
  } catch (error) {
    return res.status(500).json({ message: "Server error" });
  }
};

export const rejectProvider = async (req, res) => {
  try {
    const provider = await Provider.findOneAndUpdate(
      { _id: req.params.providerId, status: "Pending" },
      { status: "Rejected" },
      { new: true, runValidators: true }
    );
    if (!provider) {
      const existing = await Provider.findById(req.params.providerId)
        .select("status")
        .lean();
      if (!existing) {
        return res.status(404).json({ message: "Provider not found" });
      }
      return res.status(409).json({
        message: `Provider application is already ${existing.status.toLowerCase()}`,
      });
    }
    await notifyProviderReviewed({ providerId: provider._id, decision: "Rejected" });
    return res.status(200).json({
      message: "Provider rejected successfully",
      provider: withoutSecrets(provider),
    });
  } catch (error) {
    return res.status(500).json({ message: "Server error" });
  }
};
