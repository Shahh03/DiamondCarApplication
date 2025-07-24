import express from "express";
import {createUser ,getUserById,loginUser,getPendingProviders ,acceptProvider ,rejectProvider} from "../controllers/user/user.controller.js";

const router = express.Router();

router.post("/user/create", createUser); //works

router.post("/user/login", loginUser) //works

router.get("/user/:userId", getUserById); // cleaner

router.get("/user/getPendingProviders", getPendingProviders);  //works
router.put("/user/acceptProvider/:providerId", acceptProvider); //works
router.put("/user/rejectProvider/:providerId", rejectProvider); //works

export default router;
