import express from "express";
import {getAllRenters, getRenterbyId ,getBookingsForRenter} from "../controllers/renter/renter.controller.js";

const router = express.Router();

  
router.get("/renter/getAll", getAllRenters); //works

router.get("/renter/get/:renterId", getRenterbyId); //works

router.get("/renter/getBookings/:renterId", getBookingsForRenter);  //works



export default router;
