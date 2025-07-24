import express from "express";
import {createReview , getAllReviewsForCar ,getAllReviewsForProvider ,getAllReviewsForRenter ,getAllReviewsForBooking} from "../controllers/review/review.controller.js";

const router = express.Router();

router.post("/review/create", createReview); //works

router.get("/review/getAllReviewsForCar/:carId", getAllReviewsForCar); //works

router.get("/review/getAllReviewsForProvider/:providerId", getAllReviewsForProvider); //works

router.get("/review/getAllReviewsForRenter/:renterId", getAllReviewsForRenter); //works

router.get("/review/getAllReviewsForBooking/:bookingId", getAllReviewsForBooking);  //works

export default router;
