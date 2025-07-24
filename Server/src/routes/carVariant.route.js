import express from "express";
import {getAllCarsForProvider ,createCarVariant,getCarVariantsByCarId} from "../controllers/carVariant/carVariant.controller.js";

const router = express.Router();


router.post("/carVariant/create", createCarVariant); //works

router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId) //works

router.get("/car/getAllCarsForProvider/:providerId", getAllCarsForProvider); //works


export default router;
