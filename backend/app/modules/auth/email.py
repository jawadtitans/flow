"""OTP email delivery. Codes are never added to the durable email outbox."""

import logging
from typing import Protocol

import httpx

from app.core.config import get_settings
from app.modules.notifications.providers import BrevoProvider, SMTPProvider

logger = logging.getLogger(__name__)


def render_template(template: str, context: dict) -> tuple[str, str]:
    subject = {"login": "Your Flow sign-in code", "reset": "Reset your Flow password"}[template]
    body = f"{context['code']}\n\n{subject}. This code expires in 10 minutes.\nIf you did not request it, ignore this email.\nFlow"
    return subject, body


class EmailProvider(Protocol):
    async def send(self, recipient: str, template: str, context: dict) -> None: ...


class ConsoleEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        if get_settings().app_env not in ("development", "testing"):
            raise RuntimeError("Console email is only available in development and testing")
        subject, body = render_template(template, context)
        logger.info("Development email to %s: %s\n%s", recipient, subject, body)


class ResendEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        settings = get_settings()
        if not settings.resend_api_key:
            raise RuntimeError("RESEND_API_KEY is required")
        subject, body = render_template(template, context)
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {settings.resend_api_key}"},
                json={
                    "from": settings.otp_mail_from,
                    "to": [recipient],
                    "subject": subject,
                    "text": body,
                },
            )
            response.raise_for_status()


class BrevoEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        subject, body = render_template(template, context)
        await BrevoProvider().send(recipient=recipient, subject=subject, body=body)


class SMTPEmailProvider:
    async def send(self, recipient: str, template: str, context: dict) -> None:
        settings = get_settings()
        if not settings.smtp_host or not settings.smtp_username or not settings.smtp_password:
            raise RuntimeError("SMTP_HOST, SMTP_USERNAME, and SMTP_PASSWORD are required")
        subject, body = render_template(template, context)
        await SMTPProvider().send(recipient=recipient, subject=subject, body=body)


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
