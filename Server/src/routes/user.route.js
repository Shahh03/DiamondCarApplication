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

const router = express.Router();

router.post("/user/create", createUser);
router.post("/user/login", loginUser);
router.post("/user/refresh", refreshSession);
router.post("/user/logout", logoutUser);
router.get("/user/session", authenticateAccessToken, getCurrentSession);

// Static routes must come before /user/:userId.
router.get("/user/getPendingProviders", getPendingProviders);
router.put("/user/acceptProvider/:providerId", acceptProvider);
router.put("/user/rejectProvider/:providerId", rejectProvider);
router.get("/user/:userId", getUserById);

export default router;
