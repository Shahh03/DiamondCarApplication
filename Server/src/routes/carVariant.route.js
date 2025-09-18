import express from "express";
import {getAllCarsForProvider ,createCarVariant,getCarVariantsByCarId ,getAllAvaiableCarVariants} from "../controllers/carVariant/carVariant.controller.js";

const router = express.Router();


router.post("/carVariant/create", createCarVariant); //works

router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId) //works

router.get("/carVariant/getAllCarsForProvider/:providerId", getAllCarsForProvider); //works

router.get("/carVariant/getAllAvailable/", getAllAvaiableCarVariants); //works


export default router;
