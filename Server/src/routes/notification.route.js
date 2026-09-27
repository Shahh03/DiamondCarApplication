import express from "express";

import {
  getNotifications,
  getUnreadNotificationCount,
  markAllNotificationsRead,
  markNotificationRead,
} from "../controllers/notification/notification.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";

const router = express.Router();

router.get("/notification", authenticateAccessToken, getNotifications);
router.get(
  "/notification/unread-count",
  authenticateAccessToken,
  getUnreadNotificationCount
);
router.patch(
  "/notification/read-all",
  authenticateAccessToken,
  markAllNotificationsRead
);
router.patch(
  "/notification/:notificationId/read",
  authenticateAccessToken,
  markNotificationRead
);

export default router;
