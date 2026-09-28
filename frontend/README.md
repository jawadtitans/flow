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

The existing authentication screens now use the FastAPI email-first flow:
email → OTP (or password when available) → getting ready → profile or home.
Password reset requests and verifies a code, then sets a password of at least
12 characters. Settings can edit profile details and revoke the current session.

Start the migrated backend and Redis first. For local development, its default
`EMAIL_PROVIDER=console` prints the six-digit code in the API log. See
[`backend/AUTH_FLOW.md`](../backend/AUTH_FLOW.md) for email-provider configuration.

```sh
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000/api/v1/
# Android emulator (the default Android URL):
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
