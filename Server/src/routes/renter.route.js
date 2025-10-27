import express from "express";
import {getAllRenters, getRenterbyId ,getBookingsForRenter , updateRenter , updateRenterCurrency , changeRenterUsername , changeRenterPassword , getWishlistforRenter , removeFromWishlist ,changeRenterProfilePicture , addToWishlist} from "../controllers/renter/renter.controller.js";
import { get } from "mongoose";
import {renterUpload  } from "../middlewares/upload.js";
const router = express.Router();
 
router.get("/renter/getAll", getAllRenters); //works

router.get("/renter/get/:renterId", getRenterbyId); //works

router.get("/renter/getBookings/:renterId", getBookingsForRenter);  //works

router.put("/renter/update/:renterId", updateRenter); //works

router.put("/renter/updateCurrency/:renterId", updateRenterCurrency); //works

router.put("/renter/changeUsername/:renterId", changeRenterUsername); //works

router.put("/renter/changePassword/:renterId", changeRenterPassword); //works

router.get("/renter/getWishlist/:renterId", getWishlistforRenter); //works

router.post("/renter/removeFromWishlist/:renterId/:carVariantId", removeFromWishlist); //works ig

router.post("/renter/addToWishlist/:renterId/:carVariantId", addToWishlist); //works


//router.post("/renter/changeProfilePicture/:renterId", changeRenterProfilePicture);

// routes/renter.route.js
router.post(
  '/renter/changeProfilePicture/:renterId',
  renterUpload.single('file'),     // expects the form-data key named "file"
  changeRenterProfilePicture
);

export default router;
