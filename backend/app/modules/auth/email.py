"""OTP email delivery. Codes are never added to the durable email outbox."""

import logging
from typing import Protocol

import httpx

from app.core.config import get_settings
from app.modules.notifications.providers import BrevoProvider, SMTPProvider

logger = logging.getLogger(__name__)


def build_otp_email(otp: str, expiry_minutes: int = 10) -> str:
    expiry_minutes = max(1, int(expiry_minutes))
    expiry_label = f"{expiry_minutes} minute{'s' if expiry_minutes != 1 else ''}"
    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Flow verification code</title>
  <style>
    @media only screen and (max-width: 600px) {{
      .email-padding {{ padding-left: 26px !important; padding-right: 26px !important; }}
      .email-container {{ border-radius: 0 !important; }}
      .main-title {{ font-size: 22px !important; line-height: 30px !important; }}
      .otp-code {{ font-size: 30px !important; letter-spacing: 6px !important; }}
      .flow-logo {{ width: 145px !important; max-width: 145px !important; }}
    }}
  </style>
</head>
<body style="margin:0; padding:0; background-color:#f4f6f8; font-family:Arial, Helvetica, sans-serif; color:#172126;">
  <div style="display:none; max-height:0; overflow:hidden; opacity:0; color:transparent; mso-hide:all;">
    Use this verification code to securely continue with Flow.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; background-color:#f4f6f8;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table class="email-container" role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; max-width:640px; background-color:#ffffff; border-radius:12px; overflow:hidden;">
          <tr>
            <td align="center" style="padding:42px 30px 24px 30px; text-align:center;">
              <img class="flow-logo" src="https://lisockinsfgyqkzmshwz.supabase.co/storage/v1/object/public/flow-logo-email/ChatGPT%20Image%20Sep%2029,%202026,%2008_47_43%20AM.png" alt="Flow" width="155" style="display:block; width:155px; max-width:155px; height:auto; margin:0 auto; border:0; outline:none; text-decoration:none;">
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:25px 52px 4px 52px;">
              <h1 class="main-title" style="margin:0 0 14px 0; font-size:25px; line-height:33px; font-weight:600; color:#111827;">Verify your email</h1>
              <p style="margin:0; font-size:14px; line-height:23px; font-weight:400; color:#5f6b74;">
                Use the verification code below to confirm your email address and continue securely with Flow.
              </p>
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:29px 52px 8px 52px;">
              <p style="margin:0 0 10px 2px; font-size:12px; line-height:18px; font-weight:600; color:#75818a; text-transform:uppercase; letter-spacing:0.8px;">Verification code</p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="otp-code" align="center" style="background-color:#f2f6f9; border:1px solid #e4eaee; border-radius:10px; padding:24px 15px; font-family:Arial, Helvetica, sans-serif; font-size:34px; line-height:42px; font-weight:700; letter-spacing:7px; color:#0F3040; text-align:center;">
                    {otp}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="email-padding" align="center" style="padding:12px 52px 0 52px;">
              <p style="margin:0; font-size:12px; line-height:20px; color:#7a8790; text-align:center;">
                This code expires in <strong style="color:#0F3040; font-weight:600;">{expiry_label}</strong>.
              </p>
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:32px 52px 10px 52px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; background-color:#f7f9fa; border-radius:8px;">
                <tr>
                  <td style="padding:18px 20px;">
                    <p style="margin:0; font-size:13px; line-height:21px; color:#606c75;">
                      <strong style="color:#26343d; font-weight:600;">Security reminder:</strong>
                      Never share this verification code with anyone. Flow will never ask you to provide your verification code by phone, message, or email.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:18px 52px 28px 52px;">
              <p style="margin:0; font-size:13px; line-height:21px; color:#6d7981;">
                If you didn't request this verification code, you can safely ignore this email.
              </p>
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:0 52px 30px 52px;">
              <p style="margin:0 0 4px 0; font-size:13px; line-height:21px; color:#5f6b74;">Best regards,</p>
              <p style="margin:0; font-size:13px; line-height:21px; font-weight:600; color:#0F3040;">Flow.af Support Team</p>
            </td>
          </tr>
          <tr>
            <td class="email-padding" style="padding:0 52px;">
              <div style="height:1px; background-color:#e7ebee; font-size:1px; line-height:1px;">&nbsp;</div>
            </td>
          </tr>
          <tr>
            <td class="email-padding" align="center" style="padding:27px 52px 36px 52px; text-align:center;">
              <p style="margin:0 0 7px 0; font-size:14px; line-height:21px; font-weight:600; color:#26343d;">Flow</p>
              <p style="margin:0 0 16px 0; font-size:12px; line-height:19px; color:#89949b;">Your personalized AI assistant for automating everyday work.</p>
              <p style="margin:0; font-size:11px; line-height:18px; color:#9aa4aa;">
                This is an automated security email. Please do not share or forward your verification code.
              </p>
            </td>
          </tr>
        </table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%; max-width:640px;">
          <tr>
            <td align="center" style="padding:18px 20px 5px 20px; font-size:11px; line-height:18px; color:#9aa4aa;">
              © 2026 Flow.af. All rights reserved.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


def render_template(template: str, context: dict) -> tuple[str, str, str]:
    subject = {"login": "Your Flow sign-in code", "reset": "Reset your Flow password"}[template]
    expiry_minutes = int(context.get("expiry_minutes", get_settings().otp_expiry_minutes))
    code = str(context["code"])
    body = f"{code}\n\n{subject}. This code expires in {expiry_minutes} minutes.\nIf you did not request it, ignore this email.\nFlow"
    html = build_otp_email(code, expiry_minutes)
    return subject, body, html


class EmailProvider(Protocol):
    async def send(self, recipient: str, template: str, context: dict) -> None: ...


class ConsoleEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        if get_settings().app_env not in ("development", "testing"):
            raise RuntimeError("Console email is only available in development and testing")
        subject, body, _ = render_template(template, context)
        logger.info("Development email to %s: %s\n%s", recipient, subject, body)


class ResendEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        settings = get_settings()
        if not settings.resend_api_key:
            raise RuntimeError("RESEND_API_KEY is required")
        subject, body, html = render_template(template, context)
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {settings.resend_api_key}"},
                json={
                    "from": settings.otp_mail_from,
                    "to": [recipient],
                    "subject": subject,
                    "text": body,
                    "html": html,
                },
            )
            response.raise_for_status()


class BrevoEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        subject, body, html = render_template(template, context)
        await BrevoProvider().send(recipient=recipient, subject=subject, body=body, html=html)


class SMTPEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        settings = get_settings()
        if not settings.smtp_host or not settings.smtp_username or not settings.smtp_password:
            raise RuntimeError("SMTP_HOST, SMTP_USERNAME, and SMTP_PASSWORD are required")
        subject, body, html = render_template(template, context)
        await SMTPProvider().send(recipient=recipient, subject=subject, body=body, html=html)


def get_email_provider() -> EmailProvider:
    settings = get_settings()
    if settings.email_provider == "brevo":
        return BrevoEmailProvider()
    if settings.email_provider == "resend":
        return ResendEmailProvider()
    if settings.email_provider == "smtp":
        return SMTPEmailProvider()
    if settings.email_provider == "console":
        return ConsoleEmailProvider()
    raise RuntimeError("EMAIL_PROVIDER must be console, resend, brevo, or smtp")
