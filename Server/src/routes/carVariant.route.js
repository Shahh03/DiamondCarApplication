import express from "express";
import {getAllCarsForProvider ,createCarVariant,getCarVariantsByCarId ,getAllAvaiableCarVariants , getCarVariantByID} from "../controllers/carVariant/carVariant.controller.js";

const router = express.Router();


router.post("/carVariant/create", createCarVariant); //works

router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId) //works

router.get("/carVariant/getAllCarsForProvider/:providerId", getAllCarsForProvider); //works

router.get("/carVariant/getAllAvailable/", getAllAvaiableCarVariants); //works

router.get("/carVariant/:carVariantId", getCarVariantByID); //works



export default router;
