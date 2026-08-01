import express from "express";

import { trackUserActivity } from "../controllers/activity/activity.controller.js";

const router = express.Router();

router.post("/activity/track", trackUserActivity);

export default router;