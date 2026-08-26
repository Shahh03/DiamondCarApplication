import streamifier from "streamifier";

import cloudinary from "../config/cloudinary.js";

const entityFolder = (entityType, entityId, assetType) => {
  const normalizedId = entityId?.toString().trim();

  if (!normalizedId) {
    throw new Error(`A ${entityType} ID is required for Cloudinary uploads`);
  }

  return `car-rental/${entityType}/${normalizedId}/${assetType}`;
};

export const cloudinaryFolders = Object.freeze({
  carVariantImages: (carVariantId) =>
    entityFolder("car-variants", carVariantId, "images"),
  renterProfile: (renterId) =>
    entityFolder("renters", renterId, "profile"),
  providerProfile: (providerId) =>
    entityFolder("providers", providerId, "profile"),
});

export const uploadBufferToCloudinary = (buffer, folder) => {
  if (!buffer) {
    return Promise.reject(new Error("An image buffer is required"));
  }

  if (!folder?.trim()) {
    return Promise.reject(new Error("A Cloudinary folder is required"));
  }

  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: "image",
      },
      (error, result) => {
        if (error) return reject(error);
        return resolve(result);
      }
    );

    streamifier.createReadStream(buffer).pipe(stream);
  });
};
