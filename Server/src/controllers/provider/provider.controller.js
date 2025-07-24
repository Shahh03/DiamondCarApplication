import Provider from "../../models/provider.js";


export const getAllProviders = async (req, res) => {
    try {
      // Fetch all providers from the database
      const providers = await Provider.find();
  
      // If no providers found, return a message
      if (providers.length === 0) {
        return res.status(404).json({ message: "No providers found" });
      }
  
      // Send the providers data in the response
      res.status(200).json(providers);
    } catch (error) {
      // Handle any errors
      res.status(500).json({ message: error.message });
    }
  };

  export const getProviderbyId = async (req, res) => {
    try {
      const providerId = req.params.providerId;
      const provider = await Provider.findById(providerId);
  
      if (!provider) {
        return res.status(404).json({ message: "Provider not found" });
      }
  
      res.status(200).json(provider);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  };

  export const getAllCarsForProvider = async (req, res) => {
    try {
      const providerId = req.params.providerId;
      const provider = await Provider.findById(providerId).populate("cars");
  
      if (!provider) {
        return res.status(404).json({ message: "Provider not found" });
      }
  
      res.status(200).json(provider.cars);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  };