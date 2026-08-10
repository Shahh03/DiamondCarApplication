import jwt from "jsonwebtoken";

const ACCOUNT_TYPES = new Set(["Renter", "Provider", "Admin"]);

export const authenticateAccessToken = (req, res, next) => {
  const authorization = req.headers.authorization ?? "";
  const [scheme, token, extra] = authorization.trim().split(/\s+/);

  if (scheme !== "Bearer" || !token || extra) {
    return res.status(401).json({ message: "Authentication required" });
  }

  if (!process.env.JWT_ACCESS_SECRET) {
    console.error("JWT_ACCESS_SECRET is not configured");
    return res.status(500).json({ message: "Authentication is not configured" });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET, {
      algorithms: ["HS256"],
    });

    if (
      typeof payload !== "object" ||
      typeof payload.sub !== "string" ||
      !ACCOUNT_TYPES.has(payload.type)
    ) {
      return res.status(401).json({ message: "Session is invalid" });
    }

    req.auth = {
      userId: payload.sub,
      type: payload.type,
    };

    return next();
  } catch (error) {
    const expired = error?.name === "TokenExpiredError";
    return res.status(401).json({
      message: expired ? "Session has expired" : "Session is invalid",
    });
  }
};
