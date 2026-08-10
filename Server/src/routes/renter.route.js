import express from "express";

import {
  addToWishlist,
  changeRenterPassword,
  changeRenterProfilePicture,
  changeRenterUsername,
  getAllRenters,
  getBookingsForRenter,
  getRenterbyId,
  getUpcomingBookingsForRenter,
  getWishlistforRenter,
  removeFromWishlist,
  updateRenter,
  updateRenterCurrency,
} from "../controllers/renter/renter.controller.js";
import { authenticateAccessToken } from "../middlewares/auth.js";
import {
  requireParamOwner,
  requireRole,
} from "../middlewares/authorization.js";
import { renterUpload } from "../middlewares/upload.js";

const router = express.Router();
const renterSelf = requireParamOwner({ parameter: "renterId", type: "Renter" });
const renterSelfOrAdmin = requireParamOwner({
  parameter: "renterId",
  type: "Renter",
  allowAdmin: true,
});

router.use("/renter", authenticateAccessToken);

router.get("/renter/getAll", requireRole("Admin"), getAllRenters);
router.get("/renter/get/:renterId", renterSelfOrAdmin, getRenterbyId);
router.get(
  "/renter/getBookings/:renterId",
  renterSelfOrAdmin,
  getBookingsForRenter
);
router.get(
  "/renter/getUpcomingBookings/:renterId",
  renterSelfOrAdmin,
  getUpcomingBookingsForRenter
);

router.put("/renter/update/:renterId", renterSelf, updateRenter);
router.put(
  "/renter/updateCurrency/:renterId",
  renterSelf,
  updateRenterCurrency
);
router.put(
  "/renter/changeUsername/:renterId",
  renterSelf,
  changeRenterUsername
);
router.put(
  "/renter/changePassword/:renterId",
  renterSelf,
  changeRenterPassword
);

router.get(
  "/renter/getWishlist/:renterId",
  renterSelf,
  getWishlistforRenter
);
router.post(
  "/renter/removeFromWishlist/:renterId/:carVariantId",
  renterSelf,
  removeFromWishlist
);
router.post(
  "/renter/addToWishlist/:renterId/:carVariantId",
  renterSelf,
  addToWishlist
);

router.post(
  "/renter/changeProfilePicture/:renterId",
  renterSelf,
  // Reject unauthorized callers before Multer reads their upload.
  renterUpload.single("file"),
  changeRenterProfilePicture
);

export default router;
