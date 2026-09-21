import asyncio
from email.message import EmailMessage

import aiosmtplib
import httpx
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import service_account

from app.core.config import get_settings


class DeliveryError(Exception):
    def __init__(self, code: str, *, permanent=False, invalid_device=False):
        super().__init__(code)
        self.code, self.permanent, self.invalid_device = code, permanent, invalid_device


class FCMProvider:
    def __init__(self):
        self.credentials = None

    async def send(self, *, token: str, notification_id: str, title: str, body: str):
        settings = get_settings()
        if not settings.push_enabled:
            raise DeliveryError("push_disabled", permanent=True)
        try:
            if self.credentials is None:
                self.credentials = service_account.Credentials.from_service_account_file(
                    settings.fcm_credentials_file,
                    scopes=["https://www.googleapis.com/auth/firebase.messaging"],
                )
            if not self.credentials.valid:
                await asyncio.to_thread(self.credentials.refresh, GoogleRequest())
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.post(
                    f"https://fcm.googleapis.com/v1/projects/{settings.fcm_project_id}/messages:send",
                    headers={"Authorization": f"Bearer {self.credentials.token}"},
                    json={
                        "message": {
                            "token": token,
                            "data": {
                                "notification_id": notification_id,
                                "title": title,
                                "body": body,
                            },
                            "android": {"priority": "high", "ttl": "86400s"},
                            "apns": {
                                "headers": {"apns-collapse-id": notification_id},
                                "payload": {
                                    "aps": {
                                        "alert": {"title": title, "body": body},
                                        "sound": "default",
                                    }
                                },
                            },
                        }
                    },
                )
            if response.is_success:
                return
            details = response.json().get("error", {}).get("details", [])
            invalid = any(item.get("errorCode") == "UNREGISTERED" for item in details)
            raise DeliveryError(
                "device_unregistered" if invalid else f"fcm_{response.status_code}",
                permanent=invalid or response.status_code == 400,
                invalid_device=invalid,
            )
        except DeliveryError:
            raise
        except Exception as exc:
            raise DeliveryError(type(exc).__name__) from exc


class SMTPProvider:
    async def send(self, *, recipient: str, subject: str, body: str):
        settings = get_settings()
        message = EmailMessage()
        message["From"], message["To"], message["Subject"] = settings.mail_from, recipient, subject
        message.set_content(body)
        try:
            await aiosmtplib.send(
                message,
                hostname=settings.smtp_host,
                port=settings.smtp_port,
                username=settings.smtp_username,
                password=settings.smtp_password,
                start_tls=settings.smtp_starttls,
                use_tls=settings.smtp_use_tls,
                timeout=10,
            )
        except Exception as exc:
            raise DeliveryError(type(exc).__name__) from exc
