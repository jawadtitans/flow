# Settings API contract and production setup

All paths are relative to the existing `API_BASE_URL` (`/api/v1/`). Existing Dio session refresh and authenticated request options are reused. No endpoint below has been implemented on the server in this checkout: `flow-backend/backend` contains bytecode, virtualenv packages, a local database and caches, but no editable application, migration, dependency or test source. The database and compiled caches were left untouched.

## Account/profile

Existing `GET me`, `PATCH auth/complete-profile`, `POST auth/set-password`, `POST auth/request-access` and `POST auth/verify-otp` are reused. Profile save still updates global `AuthController.user` from the server response. Name fields trim whitespace and accept up to 80 characters; birthdays are serialized as calendar `YYYY-MM-DD`, never converted to UTC. The existing shared Flow date dialog is retained.

Extend `GET me` and profile responses with optional `phone_number` (E.164), `phone_verified` (boolean) and the existing `has_password` field. Never return another user's profile.

| Endpoint | Request | Response / behavior |
| --- | --- | --- |
| `POST me/phone/request` | `{phone: "+93701234567"}` | `{verification_id: "opaque-id"}`; normalize/validate again on server; send SMS via configured provider |
| `POST me/phone/verify` | `{verification_id, code}` | `{}` only after successful verification; following `GET me` returns verified number |
| `POST me/security/password` | `{current_password, new_password}` | `{}` after verifying current password and enforcing the actual server policy; atomically revoke all sessions, then client clears session and returns to sign-in |

Phone challenges must bind the authenticated user, proposed phone, expiry, attempt count and resend cooldown. A resend invalidates the previous challenge. Store hashed OTPs, apply rate limits, reject replay and do not update the current verified phone until verification succeeds. Apply a uniqueness policy consistent with the product. UI does not mark numbers verified locally. Stateless/deep-linked Verify Phone without its challenge disables submission.

For passwordless users, existing `auth/set-password` is used rather than asking for a nonexistent current password. Reject password changes that violate server policy. Never include passwords in access logs, traces, analytics or exceptions. Apply recent re-authentication if required by the server's security policy.

## TOTP MFA

| Endpoint | Request | Response |
| --- | --- | --- |
| `GET me/security/mfa` | authenticated | `{enabled: false, recovery_available: true}` |
| `POST me/security/mfa/setup` | `{password}`; existing session + recent reauthentication | `{setup_id, otpauth_uri, manual_key}` |
| `POST me/security/mfa/verify` | `{setup_id, code}` | `{recovery_codes: ["..."]}`; empty/omitted only when unsupported |
| `POST me/security/mfa/recovery` | `{code}`; fresh valid authenticator/recovery verification | `{recovery_codes: ["..."]}`; invalidate old codes atomically |
| `POST me/security/mfa/disable` | `{code}`; fresh valid verification | `{}`; invalidate TOTP and recovery credentials |
| `POST auth/mfa/verify` | `{challenge_id, code}` | existing `{access_token, refresh_token}` token envelope after valid TOTP or recovery code |

Password/OTP authentication responses must return `{mfa_required: true, challenge_id}` instead of session tokens when additional verification is required. The frontend handles this challenge and routes to `/auth/mfa`; no protected session is established before verification. Enforce MFA across all applicable sign-in/reset/recovery routes. Passkeys may satisfy strong authentication if the server explicitly allows that policy. Require strong recovery verification before account or MFA reset.

Setup state must expire, bind the user, and remain pending until a valid code is supplied. Encrypt the TOTP secret at rest server-side; return it only for pending enrollment over TLS. Rate-limit setup/verification, reject reused time-step codes, and validate an appropriate clock window. Recovery codes are one-time, cryptographically generated and hashed on the server. Client setup secrets exist only in the current page's memory; no persistence or logging. Recovery-code acknowledgement gates leaving the MFA page.

Passwordless enrollment currently supplies an empty password: the server must accept only a session with sufficiently recent email/passkey verification or return a clear re-authentication-required error. A dedicated step-up token contract can be added to the repository when the server defines it; enrollment is never simulated.

## Passkeys / WebAuthn

| Endpoint | Request | Response |
| --- | --- | --- |
| `POST auth/passkeys/register/options` | authenticated `{}` | `{challenge_id, publicKey: <standard WebAuthn creation options>}` |
| `POST auth/passkeys/register/verify` | authenticated `{challenge_id, credential: <standard public credential response>}` | `{}` after verification/storage |
| `POST auth/passkeys/authenticate/options` | public `{}` | `{challenge_id, publicKey: <standard WebAuthn request options>}` |
| `POST auth/passkeys/authenticate/verify` | public `{challenge_id, credential: <standard assertion response>}` | existing `{access_token, refresh_token}` token envelope |
| `GET me/passkeys` | authenticated | `{credentials: [{id, display_name, provider?, created_at, last_used_at?}]}` |
| `PATCH me/passkeys/{id}` | `{display_name}`; trimmed 1–80 chars | `{}` |
| `DELETE me/passkeys/{id}` | authenticated, recent verification per policy | `{}` |

`PasskeyService` sends native registration/assertion responses to these endpoints; registration success requires server verification. The `passkeys` plugin uses Android Credential Manager and Apple AuthenticationServices. The sign-in screen also offers real native passkey authentication. Private keys never leave the provider/device.

Server records: id, user_id, unique credential_id, public_key, sign_count, aaguid, transports/provider metadata, backup eligibility/state, display_name, created_at, last_used_at. Validate challenge binding/expiry/single-use, expected origin, RP ID, user presence/verification, supported algorithm, attestation/assertion signatures, credential ownership and counter/backup rules using a maintained WebAuthn library. Never trust client metadata as proof. Use transactions and uniqueness constraints. Return actionable safe errors for invalid/expired challenges, duplicate credentials and unavailable providers.

Production setup:

- Choose the actual RP domain and production Android application ID / iOS bundle ID (the project still uses example IDs).
- Serve `https://<rp-domain>/.well-known/assetlinks.json` with `delegate_permission/common.get_login_creds`, the real package name, and debug/release/Play **app-signing** SHA-256 fingerprints as applicable.
- Add `webcredentials:<rp-domain>` to Runner's Associated Domains entitlements. Serve `https://<rp-domain>/.well-known/apple-app-site-association` containing the real Apple Team ID + bundle ID in `webcredentials.apps`.
- Configure the server's origin allowlist for Android certificate-derived origins, approved Apple RP/domain behavior and web origins. Do not wildcard origins.
- No guessed domain or certificate was installed in manifests/entitlements. Existing keychain entitlement remains intact.

## Subscriptions

`GET me/subscription` (authenticated):

```json
{
  "tier": "free",
  "features": [
    {"title": "Localized supported feature title", "tiers": ["free", "pro", "max"]}
  ],
  "prices": [
    {"tier": "pro", "period": "monthly", "formatted_price": "Store-provided localized price", "product_id": "actual-store-product"}
  ]
}
```

Only real supported features belong in this response. Tier values: free/pro/max; periods: monthly/yearly. Server titles can be localized using the account's selected locale when future translations ship. Validate JSON on server and treat malformed or unknown states as unavailable on client.

`SubscriptionBilling` exposes `purchase(PlanPrice)`, `restore()`, `manage()` and `available`. Operations return a typed `BillingOutcome` (success, pending, cancelled or restoreRequired); the UI shows pending/restore states and waits for authoritative entitlement refresh. The shipped adapter explicitly reports unconfigured billing and cannot grant entitlements. The CTA and restore buttons remain disabled until replaced with a real mobile store integration. There are no fake prices, local premium flags, or payment success states.

Required integration: create Play Console/App Store subscription products and base plans, install/configure StoreKit/Google Play Billing or RevenueCat, supply store product prices, validate receipts/purchase tokens on the server, consume signed store notifications, and return authoritative entitlement changes through `me/subscription`. Cover pending purchases, cancellation, renewal, grace periods, refunds, revocation and restore. Implement management links using the real store/account. Do not enable billing simply by changing `available` to true.

## Device lock, permissions and widgets

Device lock uses secure storage with random salt, PBKDF2-HMAC-SHA256 (210,000 iterations, 256 bits), six-digit PIN confirmation, biometric enrollment check and verification, persisted retry throttling, monotonic background timing and cold-start locking. Protected content is offstage while locked/backgrounded, preserving Navigator state without rendering or exposing its semantics. Secure-storage failures prevent exposing authenticated content. Android uses FLAG_SECURE; iOS covers the scene when inactive. Email account recovery requires the existing server OTP flow; MFA-enabled recovery must finish the additional MFA challenge before the lock is reset. Do not weaken server recovery policy to make this work.

Permissions come directly from `permission_handler`; returning from OS Settings refreshes them. Photos supports limited access; files use the system picker. No phone-level permission is requested because current Flow features do not need it. On Android before media permissions exist, use picker-based access. No startup permission prompt is added. Configure any future permission only when a feature requires it.

Android widget has native RemoteViews, receiver metadata, supported-launcher pin flow and immutable PendingIntents. iOS has a WidgetKit extension target embedded in Runner, with deployment target iOS 17. Set matching signing teams and a real extension bundle ID, then build on macOS/Xcode. Static widgets contain no account data and need no App Group. `flow://widget/ask` opens agent input; `flow://widget/voice` opens an honest unavailable message because the repository has no voice-conversation implementation yet.

English is the sole selectable app locale. Generated ARB localization delegates provide locale/direction infrastructure for future RTL translations. Add completed ARB resources, register their locale in `supportedSettingsLanguages`, and expose selection only after screens are translated.

## Error contract

Use HTTP 401 for session expiry, 403 for forbidden actions, 409 for conflicts, 410 for expired challenges, 422 for validation, 429 for retry throttling, and 503 for unavailable services. Return human-readable safe `{detail: "..."}` responses; never stack traces or secrets. Account endpoints inherit the existing access-token refresh/expiry callback. Challenge endpoints enforce their own authenticated/public policy. All action pages retain a retry path and prevent concurrent submissions. Server operations must be idempotent where appropriate.

## Database migrations

None applied in this checkout. When backend source is restored, add migrations for phone verification challenges, MFA enrollment/recovery state, WebAuthn challenges/public credentials, and authoritative subscription state/store events. Preserve all existing data; apply migration tests against a copy and deploy using the repository's original migration tool. The existing `flow.db` was neither inspected for user data nor modified.
