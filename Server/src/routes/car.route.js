import express from "express";
import {createCar ,getAllCars } from "../controllers/car/car.controller.js";

const router = express.Router();

router.post("/car/create", createCar); //works
router.get("/car/getAllCars", getAllCars); //works

export default router;
