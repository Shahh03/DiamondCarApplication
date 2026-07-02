import express from "express";
import {getAllCarsForProvider ,createCarVariant,getCarVariantsByCarId ,getAllAvaiableCarVariants , getCarVariantByID , uploadCarVariantImages} from "../controllers/carVariant/carVariant.controller.js";

const router = express.Router();
import { carUpload } from "../middlewares/upload.js";

router.post("/carVariant/create", createCarVariant); //works

router.get("/carVariant/getCarVariantsByCarId/:carId", getCarVariantsByCarId) //works

router.get("/carVariant/getAllCarsForProvider/:providerId", getAllCarsForProvider); //works

router.get("/carVariant/getAllAvailable/", getAllAvaiableCarVariants); //works

router.get("/carVariant/:carVariantId", getCarVariantByID); //works

router.post(
  "/carVariant/uploadCarVariantImages/:carVariantId",
  carUpload.array("files", 10),
  uploadCarVariantImages
);

export default router;
