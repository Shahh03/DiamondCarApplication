import nodemailer from "nodemailer";

let transporter;

const requiredEmailConfiguration = () => {
  const required = [
    "SMTP_HOST",
    "SMTP_PORT",
    "SMTP_USER",
    "SMTP_PASS",
    "SMTP_FROM",
  ];

  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(`Missing email configuration: ${missing.join(", ")}`);
  }
};

const emailTransporter = () => {
  if (transporter) return transporter;

  requiredEmailConfiguration();
  const port = Number(process.env.SMTP_PORT);

  transporter = nodemailer.createTransport({
    pool: true,
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    requireTLS: port !== 465,
    connectionTimeout: 5_000,
    greetingTimeout: 5_000,
    socketTimeout: 10_000,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  return transporter;
};

export const verifyEmailTransport = async () => {
  await emailTransporter().verify();
};

export const sendPasswordResetOtp = async ({ to, otp }) => {
  await emailTransporter().sendMail({
    from: process.env.SMTP_FROM,
    to,
    subject: "Your DiamondCar password reset code",
    text: `Your DiamondCar password reset code is ${otp}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
    html: `
      <div style="background:#f4f7fb;padding:32px 16px;font-family:Arial,sans-serif;color:#0f172a">
        <div style="max-width:520px;margin:auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:20px;padding:32px">
          <div style="font-size:20px;font-weight:800;color:#1d4ed8">DiamondCar</div>
          <h1 style="font-size:24px;margin:24px 0 8px">Reset your password</h1>
          <p style="color:#64748b;line-height:1.6">Enter this code in the DiamondCar app:</p>
          <div style="margin:24px 0;padding:18px;text-align:center;background:#eff6ff;border-radius:14px;font-size:32px;font-weight:800;letter-spacing:10px;color:#1d4ed8">${otp}</div>
          <p style="color:#64748b;line-height:1.6">The code expires in 10 minutes and can only be used once.</p>
          <p style="color:#94a3b8;font-size:13px;line-height:1.5">If you did not request a password reset, no action is required.</p>
        </div>
      </div>
    `,
  });
};
