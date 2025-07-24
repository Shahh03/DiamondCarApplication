import express from "express";
import {createComplaint ,getAllComplaints ,getComplaintbyRenterId ,AdminReplyToComplaint} from "../controllers/complaint/complaint.controller.js";
import { Admin } from "mongodb";

const router = express.Router();


router.post("/complaint/create", createComplaint); //works

router.get("/complaint/getAll", getAllComplaints); //works

router.get("/complaint/get/:renterId", getComplaintbyRenterId);//works

router.put("/complaint/AdminReply/:complaintId", AdminReplyToComplaint);//works


export default router;
