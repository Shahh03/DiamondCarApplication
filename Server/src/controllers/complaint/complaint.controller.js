import Complaint from "../../models/complaint.js";
import Renter from "../../models/renter.js";


export const createComplaint = async (req, res) => {
    try {
        const { renter, title, body } = req.body;

        // Validate required fields
        if (!renter || !title || !body) {
            return res.status(400).json({ message: "All fields are required" });
        }

        // Optional: Check if renter exists
        const renterExists = await Renter.findById(renter);
        if (!renterExists) {
            return res.status(404).json({ message: "Renter not found" });
        }

        // Create a new complaint
        const newComplaint = new Complaint({ renter, title, body });
        await newComplaint.save();

        res.status(201).json({ message: "Complaint created successfully", complaint: newComplaint });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};


export const getAllComplaints = async (req, res) => {
    try{
        const complaints = await Complaint.find();
        res.status(200).json(complaints);
    }
    catch(error){
        res.status(500).json({message : error.message});
    }
}

export const getComplaintbyRenterId = async (req, res) => {
    try {
        const { renterId } = req.params;

        // Fetch complaints directly
        const complaints = await Complaint.find({ renter: renterId });


        res.status(200).json(complaints);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};


export const AdminReplyToComplaint = async (req, res) => {
    try{
        const {complaintId} = req.params;
        const {reply} = req.body;
        const complaint = await Complaint.findById(complaintId);    
        if(!complaint){
            return res.status(404).json({message : "Complaint not found"});
        }
        complaint.adminReplies.push(reply);
        complaint.status = "Resolved";
        await complaint.save();
        res.status(200).json({message : "Complaint replied successfully"});
    }catch(error){
        res.status(500).json({message : error.message});
        }

    }
