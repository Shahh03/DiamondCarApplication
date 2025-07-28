import express from "express";
import {getAllRenters, getRenterbyId ,getBookingsForRenter , updateRenter , updateRenterCurrency , changeRenterUsername , changeRenterPassword} from "../controllers/renter/renter.controller.js";

const router = express.Router();

  
router.get("/renter/getAll", getAllRenters); //works

router.get("/renter/get/:renterId", getRenterbyId); //works

router.get("/renter/getBookings/:renterId", getBookingsForRenter);  //works

router.put("/renter/update/:renterId", updateRenter); //works

router.put("/renter/updateCurrency/:renterId", updateRenterCurrency); //works

router.put("/renter/changeUsername/:renterId", changeRenterUsername); //works

router.put("/renter/changePassword/:renterId", changeRenterPassword); //works


export default router;
