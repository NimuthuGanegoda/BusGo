import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// ── Password reset PIN ────────────────────────────────────────────────────────
export async function sendPasswordResetPin(email, pin, fullName) {
  const mailOptions = {
    from: `"BusGo" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'BusGo – Your Password Reset PIN',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f8fafc; border-radius: 12px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #0a2342; font-size: 28px; letter-spacing: 4px; margin: 0;">BUSGO</h1>
          <p style="color: #6b7280; font-size: 13px; margin-top: 4px;">Smart Bus Travel, Simplified</p>
        </div>
        <div style="background: white; border-radius: 10px; padding: 24px; border-top: 3px solid #1a6fa8;">
          <p style="color: #1f2937; font-size: 15px;">Hi ${fullName},</p>
          <p style="color: #6b7280; font-size: 14px;">Your password reset PIN is:</p>
          <div style="text-align: center; margin: 24px 0;">
            <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #0a2342; background: #f0f7ff; padding: 16px 24px; border-radius: 10px; display: inline-block;">
              ${pin}
            </span>
          </div>
          <p style="color: #6b7280; font-size: 13px; text-align: center;">This PIN expires in <strong>10 minutes</strong>.</p>
          <p style="color: #9ca3af; font-size: 12px; text-align: center; margin-top: 16px;">If you didn't request this, please ignore this email.</p>
        </div>
      </div>
    `,
  };
  await transporter.sendMail(mailOptions);
}

// ── Email verification PIN (sent after registration) ─────────────────────────
export async function sendEmailVerificationPin(email, pin, fullName) {
  const mailOptions = {
    from: `"BusGo" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'BusGo – Verify Your Email Address',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f8fafc; border-radius: 12px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #0a2342; font-size: 28px; letter-spacing: 4px; margin: 0;">BUSGO</h1>
          <p style="color: #6b7280; font-size: 13px; margin-top: 4px;">Smart Bus Travel, Simplified</p>
        </div>
        <div style="background: white; border-radius: 10px; padding: 24px; border-top: 3px solid #16a34a;">
          <p style="color: #1f2937; font-size: 15px;">Hi ${fullName},</p>
          <p style="color: #6b7280; font-size: 14px;">Welcome to BusGo! Please verify your email address using the PIN below:</p>
          <div style="text-align: center; margin: 24px 0;">
            <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #0a2342; background: #f0fdf4; padding: 16px 24px; border-radius: 10px; display: inline-block;">
              ${pin}
            </span>
          </div>
          <p style="color: #6b7280; font-size: 13px; text-align: center;">This PIN expires in <strong>10 minutes</strong>.</p>
          <p style="color: #9ca3af; font-size: 12px; text-align: center; margin-top: 16px;">If you didn't create a BusGo account, please ignore this email.</p>
        </div>
      </div>
    `,
  };
  await transporter.sendMail(mailOptions);
}

// ── Admin temp password (sent by developer after approving recovery request) ──
export async function sendAdminTempPassword(email, tempPassword, fullName) {
  const mailOptions = {
    from: `"BusGo Axis" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'BusGo Axis – Temporary Admin Password',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f8fafc; border-radius: 12px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #0a2342; font-size: 28px; letter-spacing: 4px; margin: 0;">BUSGO AXIS</h1>
          <p style="color: #6b7280; font-size: 13px; margin-top: 4px;">Admin Panel – Account Recovery</p>
        </div>
        <div style="background: white; border-radius: 10px; padding: 24px; border-top: 3px solid #d97706;">
          <p style="color: #1f2937; font-size: 15px;">Hi ${fullName},</p>
          <p style="color: #6b7280; font-size: 14px;">
            Your password recovery request has been approved by a developer.
            Use the temporary password below to log in:
          </p>
          <div style="text-align: center; margin: 24px 0;">
            <span style="font-size: 22px; font-weight: 800; letter-spacing: 4px; color: #0a2342;
              background: #fffbeb; padding: 16px 24px; border-radius: 10px;
              display: inline-block; border: 2px solid #f59e0b; font-family: monospace;">
              ${tempPassword}
            </span>
          </div>
          <div style="background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: 12px 16px; margin-top: 16px;">
            <p style="color: #dc2626; font-size: 13px; margin: 0; font-weight: 600;">
              Important Security Instructions:
            </p>
            <ul style="color: #6b7280; font-size: 13px; margin: 8px 0 0; padding-left: 16px;">
              <li>This is a one-time temporary password</li>
              <li>You will be required to set a new password immediately after login</li>
              <li>You must also set a new recovery PIN and answer security questions</li>
              <li>Do not share this password with anyone</li>
              <li>Delete this email after logging in</li>
            </ul>
          </div>
          <p style="color: #9ca3af; font-size: 12px; text-align: center; margin-top: 20px;">
            If you did not request a password reset, contact your developer immediately.
          </p>
        </div>
        <p style="color: #9ca3af; font-size: 11px; text-align: center; margin-top: 16px;">
          BusGo Axis Admin Panel · Confidential
        </p>
      </div>
    `,
  };
  await transporter.sendMail(mailOptions);
}
