# Email-first authentication

The Flutter app uses the email-first flow. Request a code with
`POST /api/v1/auth/request-access` (`email`), then either verify it with
`POST /auth/verify-otp` (`email`, `code`) or use `POST /auth/login-password`
(`email`, `password`). Paths after the first example are relative to `/api/v1`.
Both sign-in methods return access/refresh tokens and `profile_completed`.
Only OTP verification creates a passwordless user; requesting a code creates
no SQL user. Email addresses are normalized to lowercase.

After sign-in, incomplete accounts submit `first_name`, `last_name` and
`birth_date` (`YYYY-MM-DD`) to authenticated `PATCH /auth/complete-profile`.
The same endpoint edits an existing profile. `/me` returns the new fields.

Forgot password uses `POST /auth/forgot-password` (`email`) followed by
`POST /auth/reset-password` (`email`, `code`, `new_password`). Passwords must
contain 12–128 characters. No breach-check service previously existed, so
the documented minimum policy is enforced without introducing an external
password lookup. Successful resets revoke every session, including access
tokens checked against the revoked sessions. Passwordless accounts are told
to use a sign-in code; this flow does not silently add a password.

## Local email and real delivery

`EMAIL_PROVIDER=console` is the development default. Codes appear only in the
API server log, never in API responses or the SQL email outbox. This provider
refuses to operate outside `development`/`testing`.

For Brevo API delivery, save these values in the backend `.env`:

```dotenv
EMAIL_PROVIDER=brevo
BREVO_API_KEY=your-brevo-api-key
BREVO_SENDER_EMAIL=your-verified-sender@example.com
BREVO_SENDER_NAME=Flow
```

Use an API key from Brevo's **SMTP & API > API Keys** settings. The backend calls
[Brevo's transactional email API](https://developers.brevo.com/reference/send-transac-email)
with the `api-key` header. No SMTP credentials or new Python packages are needed.
The sender address must match a verified sender in your Brevo account.
`BREVO_SENDER_EMAIL` takes precedence over `MAIL_FROM`; when omitted,
`MAIL_FROM="Flow <your-verified-sender@example.com>"` supplies the sender instead.
`BREVO_SENDER_NAME` overrides the display name from `MAIL_FROM` (default: `Flow`).
`EMAIL_FROM` is also accepted as an alias for `MAIL_FROM`, and `EMAIL_FROM_NAME`
as an alias for `BREVO_SENDER_NAME`, so existing Brevo configurations using
those names work without renaming their settings.
Missing API keys or invalid sender addresses fail configuration validation.

Brevo handles both sign-in/password-reset codes and queued verification/reset
links. OTPs are sent immediately; queued emails require the Celery worker and
scheduler. Restart the API, worker, and scheduler after changing `.env`. Test by requesting a code in the mobile app
and checking the recipient's inbox and Brevo transactional logs. A successful
API response means Brevo accepted the email; final delivery is tracked by Brevo.
Rate limits, timeouts, and server errors remain retryable for queued mail;
other 4xx errors mark the queued email as failed without storing response bodies.

Resend remains available for OTP delivery:

```dotenv
EMAIL_PROVIDER=resend
RESEND_API_KEY=your-resend-key
OTP_MAIL_FROM=Flow <onboarding@resend.dev>
```

The [Resend API](https://resend.com/docs/api-reference/emails/send-email) is
called server-side. Its [test sender](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)
can deliver only to the email on the Resend account; delivering to other users
requires a verified sending domain and an appropriate `OTP_MAIL_FROM`.
Delivery failure returns 503 and invalidates that code. The console provider
lets local development work without email-service credentials.

## Redis and compatibility

Codes live only in the authentication Redis (`RATE_LIMIT_REDIS_URL`), under
`otp:login:{email}` or `otp:reset:{email}`. Each hash has a keyed HMAC digest
and attempt count, with a 600-second TTL. Lua scripts atomically consume codes,
invalidate them after five wrong attempts, and replace them on resend.
Never copy production authentication Redis data into a developer environment.

Each purpose permits three deliveries per email and twenty per source IP in
15 minutes (`OTP_EMAIL_RATE_LIMIT`, `OTP_IP_RATE_LIMIT`). Existing endpoint IP
limits also apply. Responses include a readable delay and `Retry-After`.
Both password-login endpoints share account backoff: the fifth failed attempt
locks for 30 seconds, with subsequent failures doubling the delay up to
15 minutes. Redis failures fail authentication closed.

The existing refresh/logout/logout-all token lifecycle is unchanged. The
staff dashboard keeps `/auth/login?client=browser` and its cookie/CSRF checks.
Its legacy reset-link request uses `/auth/forgot-password?client=browser`;
old reset links remain accepted with the new 12-character password minimum.
Those legacy account emails use the durable outbox with Brevo when
`EMAIL_PROVIDER=brevo`; other providers retain the existing SMTP delivery.

Apply `alembic upgrade head` before starting the updated app. Migration 0003
splits the actual legacy `display_name` field into best-effort first/last names
and retains the original display name for older clients. The stored
`is_verified` column becomes `email_verified`, with `is_verified` retained as
a model/API alias. Legacy accounts without birth dates remain incomplete.
Downgrading refuses to discard the passwordless model if such users exist.

The account-existence response and passwordless signup are intentional parts
of the supplied specification. No new-password prompt is added to signup.
