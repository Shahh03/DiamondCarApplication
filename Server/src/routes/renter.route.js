import express from "express";
import {getAllRenters, getRenterbyId ,getBookingsForRenter , updateRenter , updateRenterCurrency} from "../controllers/renter/renter.controller.js";

const router = express.Router();

  
router.get("/renter/getAll", getAllRenters); //works

router.get("/renter/get/:renterId", getRenterbyId); //works

router.get("/renter/getBookings/:renterId", getBookingsForRenter);  //works

router.put("/renter/update/:renterId", updateRenter); //works

router.put("/renter/updateCurrency/:renterId", updateRenterCurrency); //works


export default router;
