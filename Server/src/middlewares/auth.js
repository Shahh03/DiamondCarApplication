import jwt from "jsonwebtoken";

export const authenticateAccessToken = (req, res, next) => {
  const authorization = req.headers.authorization ?? "";
  const [scheme, token] = authorization.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Authentication required" });
  }

  if (!process.env.JWT_ACCESS_SECRET) {
    return res.status(500).json({ message: "Authentication is not configured" });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
    req.auth = {
      userId: payload.sub,
      type: payload.type,
    };
    return next();
  } catch {
    return res.status(401).json({ message: "Session has expired" });
  }
};
