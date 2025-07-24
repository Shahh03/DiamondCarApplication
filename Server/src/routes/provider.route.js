import express from "express";
import {getAllProviders,getProviderbyId} from "../controllers/provider/provider.controller.js";

const router = express.Router();

router.get("/provider/getAll", getAllProviders); //works
router.get("/provider/get/:providerId", getProviderbyId); //works
export default router;
