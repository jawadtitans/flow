# Local backend for the mobile app

The dashboard is optional. This API runs independently with Python 3.12,
SQLite, Redis, and Celery for reminder processing.

## Start

From this directory (`flow-backend/backend`):

```bash
./scripts/start-local.sh
```

The launcher uses the existing `.venv` and `.env`, applies database migrations,
and starts the API, one Celery worker, and the scheduler. Redis must already
be running at `127.0.0.1:6379`. Stop a foreground run with Ctrl+C.

- API: <http://localhost:8000/api/v1/>
- Interactive API documentation: <http://localhost:8000/docs>
- Readiness check (database and Redis): <http://localhost:8000/ready>
- API / login-code log: `.local/api.log`
- Background job logs: `.local/worker.log` and `.local/beat.log`

This checkout's `.env` uses Redis databases 8–11 to separate its cache,
authentication, task queue, and results from the other local Flow containers.
The new SQLite database is `flow.db`; keep it to preserve local accounts and
app data. Data from the previous Windows installation is not included.

The initial background launch records its PID in `.local/backend.pid`.
To stop that run before starting again in a terminal:

```bash
kill "$(cat .local/backend.pid)"
```

## Connect the Flutter app

For a physical Android phone connected by USB, run:

```bash
adb reverse tcp:8000 tcp:8000
cd /home/jawad/Desktop/flow-mobile/frontend
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
```

Repeat `adb reverse` after reconnecting the phone. The app's normal Android
default is the emulator address, so the `--dart-define` is needed on a phone.
Restart the Flutter app with that argument; hot reload alone does not change it.

For an Android emulator, use `http://10.0.2.2:8000/api/v1/` (the app default).
For a phone on the same Wi-Fi, use the computer's current LAN IP instead;
at setup time that was `http://192.168.0.100:8000/api/v1/`.
The API listens on all local interfaces. Use a debug mobile build for local HTTP.

A browser preview can run on the configured CORS origin:

```bash
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000/api/v1/
```

## Sign in

For real email delivery, configure `EMAIL_PROVIDER=brevo`, `BREVO_API_KEY`,
`BREVO_SENDER_EMAIL`, and `BREVO_SENDER_NAME` in `.env`, then restart the local
backend. Enter an email in the mobile app and check that inbox for the code.
See [AUTH_FLOW.md](AUTH_FLOW.md#local-email-and-real-delivery) for sender settings.

With `EMAIL_PROVIDER=console`, read the six-digit code from the API log:

```bash
tail -f /home/jawad/Desktop/flow-mobile/flow-backend/backend/.local/api.log
```

`EMAIL_PROVIDER=console` prints local codes instead of sending real emails.
Complete the profile after signing in. Firebase push delivery is disabled;
the reminder worker can still create notifications in the API.
See [AUTH_FLOW.md](AUTH_FLOW.md) for real email delivery configuration.

The mobile README describes API integration for authentication, profiles, and
sessions. Task and routine screens retain their existing data behavior;
starting the backend does not add missing mobile API integration.

## Recreate the Python environment if needed

```bash
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.lock
```

The local `.env` contains development settings and generated JWT secrets.
Keep it private; it is ignored along with `.venv`, `.local`, and `flow.db`.
