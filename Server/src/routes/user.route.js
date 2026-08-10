import express from "express";

import {
  acceptProvider,
  createUser,
  getCurrentSession,
  getPendingProviders,
  getUserById,
  loginUser,
  logoutUser,
  refreshSession,
  rejectProvider,
} from "../controllers/user/user.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireAccountSelfOrAdmin,
  requireRole,
  restrictPublicSignup,
} from "../middlewares/authorization.js";

const router = express.Router();

router.post("/user/create", restrictPublicSignup, createUser);
router.post("/user/login", loginUser);
router.post("/user/refresh", refreshSession);
router.post("/user/logout", logoutUser);

router.get("/user/session", authenticateAccessToken, getCurrentSession);

// Static routes must come before /user/:userId.
router.get(
  "/user/getPendingProviders",
  authenticateAccessToken,
  requireRole("Admin"),
  getPendingProviders
);
router.put(
  "/user/acceptProvider/:providerId",
  authenticateAccessToken,
  requireRole("Admin"),
  acceptProvider
);
router.put(
  "/user/rejectProvider/:providerId",
  authenticateAccessToken,
  requireRole("Admin"),
  rejectProvider
);
router.get(
  "/user/:userId",
  authenticateAccessToken,
  requireAccountSelfOrAdmin("userId"),
  getUserById
);

export default router;
