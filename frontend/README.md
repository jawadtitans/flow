# Flow frontend

Flutter UI for Flow.

## Run

```sh
flutter pub get
flutter run
```

The supplied Roboto weights and italics are bundled in `assets/fonts/roboto/`
with their OFL license. The four welcome headline icons are in
`assets/welcome/icons/`.

## Check

```sh
flutter analyze
flutter test
flutter build web
```
## Backend authentication

The email screen sends a verification code for sign-in or signup. Existing
accounts with a password can select "Try another way" below OTP confirmation.
New accounts follow OTP -> password and confirmation -> personal details ->
discovery source -> interests -> avatar introductions -> getting ready -> home.
Onboarding completion is saved separately from profile completion, so an
interrupted signup resumes before home becomes available.
Password reset requests and verifies a code, then sets a password of at least
12 characters. Accounts Center supports profile details and photo editing.
Settings asks for logout confirmation. Account deletion requires a dialog,
typing `Delete`, and accepting the final permanent-deletion warning.

Deploy the updated backend and run `alembic upgrade head` from
`flow-backend/backend` before using the new account APIs. Migration
`0004_account_onboarding` adds saved onboarding answers and profile photos.
The default API is `https://flow-gxog.onrender.com/api/v1/`. A `404 Not Found`
when creating a password means that deployment is missing
`POST /api/v1/auth/set-password`; updating the mobile app alone cannot add it.
Deploy the backend branch containing the account changes, including
`requirements.lock`. The Docker startup script applies migrations automatically.
Confirm the deployed schema at `/api/v1/openapi.json` includes the password
endpoint before retrying signup. For local testing, override `API_BASE_URL`
as shown below rather than contacting the hosted API.
Start the migrated backend and Redis first. For local development, its default
`EMAIL_PROVIDER=console` prints the six-digit code in the API log. See
[`AUTH_FLOW.md`](../flow-backend/backend/AUTH_FLOW.md) for email-provider configuration.

```sh
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000/api/v1/
# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/
```

For a physical phone, pass your development machine's reachable LAN address
and bind the local backend to that interface. Use HTTPS for release builds.
Browser previews must use an origin listed in backend `CORS_ORIGINS`;
`http://localhost:8080` is included in the development configuration.

Access tokens stay in memory. Native refresh tokens use platform secure
storage; expired access tokens are refreshed once with concurrent requests
sharing the same refresh operation. Native app startup restores the session.
The web preview keeps refresh tokens in tab memory, so reloading requires a
new sign-in. Passwords and OTPs are never persisted. A failed network request
during restoration keeps the stored refresh token and offers retry.

The integration covers authentication, profile completion/editing and session
lifecycle. Task, routine and other feature screens retain their existing data
behavior; they are outside the supplied auth specification.
