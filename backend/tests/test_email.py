import json
from datetime import timedelta

import httpx
import pytest
from pydantic import SecretStr, ValidationError
from sqlalchemy import select

from app.core.config import Settings, get_settings
from app.modules.auth.email import get_email_provider
from app.modules.notifications import providers
from app.modules.notifications.models import OutboundEmail
from app.modules.notifications.providers import BrevoProvider, DeliveryError
from app.modules.notifications.service import deliver_email
from app.shared.time import utcnow


@pytest.fixture
def brevo_http(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "email_provider", "brevo")
    monkeypatch.setattr(settings, "brevo_api_key", SecretStr("test-brevo-key"))
    monkeypatch.setattr(settings, "brevo_sender_email", "hello@example.com")
    monkeypatch.setattr(settings, "brevo_sender_name", "Flow")
    client_type = httpx.AsyncClient
    requests = []

    def respond(status=201, error=None):
        def handle(request):
            requests.append(request)
            if error:
                raise error("private provider detail", request=request)
            return httpx.Response(status, json={"messageId": "test-id"})

        monkeypatch.setattr(
            providers.httpx,
            "AsyncClient",
            lambda **kwargs: client_type(transport=httpx.MockTransport(handle), **kwargs),
        )
        return requests

    return respond


@pytest.mark.parametrize(
    ("template", "subject"),
    [("login", "Your Flow sign-in code"), ("reset", "Reset your Flow password")],
)
async def test_brevo_otp_request_contract(brevo_http, template, subject):
    requests = brevo_http()
    await get_email_provider().send("person@example.com", template, {"code": "012345"})
    assert len(requests) == 1
    request = requests[0]
    assert request.method == "POST"
    assert str(request.url) == "https://api.brevo.com/v3/smtp/email"
    assert request.headers["api-key"] == "test-brevo-key"
    assert request.headers["content-type"] == "application/json"
    payload = json.loads(request.content)
    assert payload["sender"] == {"email": "hello@example.com", "name": "Flow"}
    assert payload["to"] == [{"email": "person@example.com"}]
    assert payload["subject"] == subject
    assert payload["textContent"].startswith("012345\n")
    assert "expires in 10 minutes" in payload["textContent"]


@pytest.mark.parametrize(
    ("status", "permanent"),
    [(400, True), (401, True), (403, True), (408, False), (429, False), (500, False), (503, False)],
)
async def test_brevo_error_classification(brevo_http, status, permanent):
    brevo_http(status)
    with pytest.raises(DeliveryError) as error:
        await BrevoProvider().send(recipient="person@example.com", subject="Test", body="Body")
    assert error.value.code == f"brevo_{status}"
    assert error.value.permanent is permanent


@pytest.mark.parametrize("failure", [httpx.ReadTimeout, httpx.ConnectError])
async def test_brevo_network_errors_are_retryable(brevo_http, failure):
    brevo_http(error=failure)
    with pytest.raises(DeliveryError) as error:
        await BrevoProvider().send(recipient="person@example.com", subject="Test", body="Body")
    assert error.value.code == f"brevo_{failure.__name__}"
    assert not error.value.permanent
    assert "private provider detail" not in str(error.value)


async def test_brevo_outbox_uses_api_and_redacts_delivered_body(env, owner, brevo_http):
    requests = brevo_http()
    async with env[1]() as db:
        assert await deliver_email(db) == 1
        item = await db.scalar(select(OutboundEmail))
        assert item.status == "sent"
        assert item.body == "[delivered]"
        assert item.last_error is None
        assert await deliver_email(db) == 0
    assert len(requests) == 1
    payload = json.loads(requests[0].content)
    assert payload["to"] == [{"email": "user@example.com"}]
    assert payload["subject"] == "Verify your Flow email"
    assert "token=" in payload["textContent"]


@pytest.mark.parametrize(("status", "state"), [(400, "failed"), (429, "retry")])
async def test_brevo_outbox_failure_and_retry(env, owner, brevo_http, status, state):
    requests = brevo_http(status)
    async with env[1]() as db:
        assert await deliver_email(db) == 1
        item = await db.scalar(select(OutboundEmail))
        assert item.status == state
        assert item.last_error == f"brevo_{status}"
        assert item.body != "[delivered]"
        if state == "retry":
            item.next_attempt_at = utcnow() - timedelta(seconds=1)
            await db.commit()
            brevo_http()
            assert await deliver_email(db) == 1
            await db.refresh(item)
            assert item.status == "sent"
            assert item.attempts == 2
    assert len(requests) == (2 if state == "retry" else 1)


async def test_brevo_otp_failure_invalidates_code(env, brevo_http, caplog):
    requests = brevo_http(503)
    response = await env[0].post(
        "/api/v1/auth/request-access", json={"email": "person@example.com"}
    )
    assert response.status_code == 503
    assert response.headers["retry-after"] == "60"
    assert not await env[2].exists("otp:login:person@example.com")
    code = json.loads(requests[0].content)["textContent"].splitlines()[0]
    assert code not in caplog.text
    assert "test-brevo-key" not in caplog.text
    assert "test-brevo-key" not in response.text


def test_brevo_settings_load_environment_and_mail_from_fallback(tmp_path, monkeypatch):
    monkeypatch.delenv("EMAIL_PROVIDER")
    for name in ("BREVO_API_KEY", "BREVO_SENDER_EMAIL", "BREVO_SENDER_NAME", "MAIL_FROM"):
        monkeypatch.delenv(name, raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text(
        "EMAIL_PROVIDER=brevo\nBREVO_API_KEY=test-key\n"
        'MAIL_FROM="Flow Support <support@example.com>"\n'
    )
    settings = Settings(_env_file=env_file)
    assert settings.email_provider == "brevo"
    assert settings.brevo_api_key.get_secret_value() == "test-key"
    assert "test-key" not in repr(settings)
    assert settings.brevo_sender == {"email": "support@example.com", "name": "Flow Support"}
    settings = Settings(
        _env_file=env_file, brevo_sender_email="hello@example.com", brevo_sender_name="Flow"
    )
    assert settings.brevo_sender == {"email": "hello@example.com", "name": "Flow"}


@pytest.mark.parametrize("key", [None, "", "   "])
def test_brevo_requires_api_key(key):
    with pytest.raises(ValidationError, match="BREVO_API_KEY is required"):
        Settings(_env_file=None, email_provider="brevo", brevo_api_key=key)


@pytest.mark.parametrize("sender", [None, "not-an-email"])
def test_brevo_requires_sender(sender):
    with pytest.raises(ValidationError, match="valid sender email") as error:
        Settings(
            _env_file=None,
            email_provider="brevo",
            brevo_api_key="test-key",
            brevo_sender_email=sender,
            mail_from="Flow <noreply@localhost>",
        )
    assert "test-key" not in str(error.value)


async def test_brevo_otp_sign_in(env, brevo_http):
    requests = brevo_http()
    client, factory, redis, _ = env
    response = await client.post(
        "/api/v1/auth/request-access", json={"email": "person@example.com"}
    )
    assert response.status_code == 200
    code = json.loads(requests[0].content)["textContent"].splitlines()[0]
    assert code not in response.text
    assert code not in str(await redis.hgetall("otp:login:person@example.com"))
    verified = await client.post(
        "/api/v1/auth/verify-otp", json={"email": "person@example.com", "code": code}
    )
    assert verified.status_code == 200
    assert verified.json()["access_token"]
    async with factory() as db:
        assert await db.scalar(select(OutboundEmail)) is None


@pytest.mark.parametrize("sender", ["hello@example.com", "Flow Team <hello@example.com>"])
def test_brevo_accepts_email_from_environment_names(tmp_path, monkeypatch, sender):
    for name in (
        "EMAIL_PROVIDER",
        "BREVO_API_KEY",
        "BREVO_SENDER_EMAIL",
        "BREVO_SENDER_NAME",
        "MAIL_FROM",
        "EMAIL_FROM",
        "EMAIL_FROM_NAME",
    ):
        monkeypatch.delenv(name, raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text(
        "EMAIL_PROVIDER=brevo\nBREVO_API_KEY=test-key\n"
        f'EMAIL_FROM="{sender}"\nEMAIL_FROM_NAME="Flow Sender"\n'
    )
    settings = Settings(_env_file=env_file)
    assert settings.email_provider == "brevo"
    assert settings.brevo_sender == {"email": "hello@example.com", "name": "Flow Sender"}


def test_brevo_sender_environment_precedence(tmp_path, monkeypatch):
    for name in (
        "EMAIL_PROVIDER",
        "BREVO_API_KEY",
        "BREVO_SENDER_EMAIL",
        "BREVO_SENDER_NAME",
        "MAIL_FROM",
        "EMAIL_FROM",
        "EMAIL_FROM_NAME",
    ):
        monkeypatch.delenv(name, raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text(
        "EMAIL_PROVIDER=brevo\nBREVO_API_KEY=test-key\n"
        "BREVO_SENDER_EMAIL=primary@example.com\nBREVO_SENDER_NAME=Primary\n"
        'MAIL_FROM="Mail From <mail@example.com>"\n'
        "EMAIL_FROM=alias@example.com\nEMAIL_FROM_NAME=Alias\n"
    )
    settings = Settings(_env_file=env_file)
    assert settings.brevo_sender == {"email": "primary@example.com", "name": "Primary"}
    assert settings.mail_from == "Mail From <mail@example.com>"
