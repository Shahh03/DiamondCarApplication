import bcrypt from "bcrypt";

const BCRYPT_ROUNDS = 12;
const BCRYPT_PATTERN = /^\$2[aby]\$\d{2}\$/;

export const isHashedPassword = (value) =>
  typeof value === "string" && BCRYPT_PATTERN.test(value);

export const hashPassword = (password) =>
  bcrypt.hash(password, BCRYPT_ROUNDS);

export const verifyPassword = async (password, storedPassword) => {
  if (!password || !storedPassword) return false;

  if (isHashedPassword(storedPassword)) {
    return bcrypt.compare(password, storedPassword);
  }

  // Temporary backwards compatibility for accounts created before bcrypt.
  return password === storedPassword;
};
