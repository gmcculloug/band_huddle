# Security Review — 2026-10-15

This review covers application authentication, authorization, browser security, OAuth, JWT handling, public endpoints, service-worker caching, and Docker deployment configuration.

## Executive Summary

The application has a generally strong band-scoping pattern and uses parameterized ActiveRecord queries, but several issues should be treated as release blockers:

- Passwords and deployment secrets can be written to logs.
- Browser endpoints do not have CSRF protection.
- Apple OAuth identity tokens are accepted without cryptographic validation.
- OAuth users can be linked to existing accounts using potentially unverified email addresses.
- PostgreSQL and unauthenticated Valkey are exposed on Docker host interfaces.
- User-controlled URLs can produce stored `javascript:` links.
- Mobile refresh tokens cannot actually be revoked.

## Critical Findings

### CRITICAL-001 — Passwords are logged

- **Location:** `lib/routes/authentication.rb:80`
- **Issue:** `POST /api/auth/login` logs the full `params` object, including the user's password.
- **Impact:** Plaintext passwords can be retained in production logs, container logs, log aggregation systems, and backups.
- **Remediation:**
  - Remove the `puts "params: #{params}"` statement.
  - Audit all request logging and error handlers for accidental parameter serialization.
  - Scrub historical logs and rotate credentials that may have been exposed.
  - Add a regression test asserting that login requests never log the password.
- **Status:** Code fixed; rotate any historically logged passwords and notify affected users

### CRITICAL-002 — CSRF protection is absent

- **Location:** Representative privileged routes: `lib/routes/bands.rb:144`, `lib/routes/bands.rb:184`, `lib/routes/bands.rb:282`
- **Issue:** No browser form includes an authenticity token, and authenticated state-changing routes rely only on ambient session cookies.
- **Impact:** A malicious third-party page can act as a logged-in victim. Exploits include adding an attacker to a band, transferring ownership, deleting data, changing public visibility, or modifying integrations.
- **Remediation:**
  - Add `Rack::Protection::AuthenticityToken` to the browser application.
  - Require a CSRF token for every authenticated state-changing browser route.
  - Keep public vote/recommendation endpoints deliberately excluded only if their abuse controls are strengthened.
  - Add tests proving a valid session without a token is rejected.
- **Status:** Code fixed; unsafe browser requests now require an authenticity token

### CRITICAL-003 — Apple identity token is not verified

- **Location:** `lib/services/oauth_service.rb:559`
- **Issue:** Apple's ID token is decoded with `JWT.decode(..., nil, false)`. Signature, issuer, audience, and expiration are not validated.
- **Impact:** Identity claims should not be trusted without validation. A flaw or compromise in the surrounding token-exchange flow could allow forged identity claims.
- **Remediation:**
  - Fetch and cache Apple's public JWKS.
  - Verify the signature using an allowed Apple signing key.
  - Enforce expected `iss`, `aud`, `exp`, `iat`, and `sub` claims.
  - Reject tokens with unsupported algorithms.
- **Status:** Open

### CRITICAL-004 — OAuth linking trusts potentially unverified email

- **Location:** `lib/services/oauth_service.rb:253`
- **Issue:** Existing users are linked to OAuth identities by email address without confirming that the provider has verified the email.
- **Impact:** An attacker may control an OAuth account's public email value and use it to link to another user's local account.
- **Remediation:**
  - Link only when the provider explicitly reports a verified email.
  - For GitHub, use the verified-email endpoint rather than the public email field from `/user`.
  - Require the existing user to authenticate and explicitly approve OAuth linking.
  - Do not silently link OAuth identities to existing password accounts.
- **Status:** Code fixed; linking now requires a provider-verified email, GitHub emails come from the verified `/user/emails` endpoint, and password accounts must confirm their password on `/auth/link_account` before an OAuth identity is attached

### CRITICAL-005 — PostgreSQL and Valkey are exposed externally

- **Location:** `docker-compose.yml:11`, `docker-compose.yml:22`
- **Issue:** PostgreSQL and an unauthenticated Valkey instance publish ports on all Docker host interfaces.
- **Impact:** Network-reachable attackers may access application data or session state, depending on host firewalling and credential strength.
- **Remediation:**
  - Remove both `ports:` entries.
  - Use `expose:` or rely on the default internal Docker network.
  - Add Valkey authentication and TLS if host access is genuinely required.
  - Bind development-only ports to `127.0.0.1`, never all interfaces.
- **Status:** Code fixed; PostgreSQL and Valkey are now reachable only within the Docker network

### CRITICAL-006 — Account-creation secret is printed during deployment

- **Location:** `docker-compose.yml:98`
- **Issue:** The application container prints `BAND_HUDDLE_ACCT_CREATION_SECRET` at startup.
- **Impact:** Anyone with access to container logs may obtain the registration secret.
- **Remediation:**
  - Remove the echo statement.
  - Rotate the secret if this deployment has already run.
  - Use Docker secrets or the platform's protected secret mechanism rather than environment defaults.
- **Status:** Code fixed; rotate the account-creation secret if the previous deployment ran

### CRITICAL-007 — User-controlled URLs can become stored `javascript:` links

- **Locations:**
  - `views/show_venue.erb:38`
  - `views/show_venue.erb:44`
  - `views/show_song.erb:57`
- **Issue:** HTML escaping does not prevent unsafe URL schemes. Venue website/map URLs and song URLs are placed directly in `href` attributes without server-side scheme validation.
- **Impact:** A band member can store a `javascript:` URL that executes in another member's or fan's browser when clicked.
- **Remediation:**
  - Add model or service validation requiring `https://` for user-facing website, streaming, map, tip, and social links.
  - Explicitly parse URLs and reject missing hosts.
  - Render a safe fallback or omit the link if a stored URL fails validation.
  - Backfill validation over existing records and review invalid values.
- **Status:** Code fixed; review existing records and clear any invalid stored values

## High Findings

### HIGH-001 — JWT revocation is ineffective

- **Locations:**
  - `lib/services/jwt_service.rb`
  - `lib/routes/mobile_api.rb:112`
- **Issue:** Refresh tokens are stateless JWTs valid for 30 days. The revoke endpoint returns success without invalidating any token.
- **Impact:** A stolen refresh token remains usable until natural expiry. Password changes, account deletion, and device logout cannot revoke mobile access.
- **Remediation:**
  - Store a hashed refresh-token identifier in a database table.
  - Associate it with user, device, creation time, expiry, and revocation state.
  - Rotate the refresh token on each refresh and detect reuse.
  - Revoke tokens on logout, password change, OAuth unlinking, and account deletion.
- **Status:** Open

### HIGH-002 — Session cookie and lifecycle hardening is incomplete

- **Location:** `app.rb:95`
- **Issue:** Session options are not explicitly configured, and the session identifier is not regenerated after login or privilege changes.
- **Impact:** Cookies may lack explicit production security attributes, and session fixation/lifetime handling is weaker than modern best practice.
- **Remediation:**
  - Configure `secure: true`, `httponly: true`, and `same_site: :lax` or `:strict` in production.
  - Regenerate the session ID after login, logout, OAuth linking, and role/ownership changes.
  - Define and enforce an absolute session lifetime and idle timeout.
- **Status:** Open

### HIGH-003 — Login has no effective brute-force defense

- **Location:** `lib/routes/authentication.rb:21`
- **Issue:** There is no application-level lockout or exponential backoff. Nginx's 10 requests/second limit still allows substantial sustained attacks.
- **Impact:** Password guessing and credential-stuffing attacks are feasible.
- **Remediation:**
  - Add per-account and per-IP throttling with exponential backoff.
  - Add temporary account lockout or step-up verification.
  - Emit security events for repeated failures.
  - Consider breached-password checks at password creation or change.
- **Status:** Open

### HIGH-004 — Broad mass assignment

- **Locations:**
  - `lib/routes/bands.rb:35`
  - `lib/routes/bands.rb:101`
  - `lib/routes/songs.rb:161`
- **Issue:** Raw nested parameters are passed to `new` or `update`.
- **Impact:** Future schema changes or omitted authorization checks can turn additional columns into client-controlled fields.
- **Remediation:**
  - Create explicit allowlists for each model and route.
  - Assign ownership, role, integration, public visibility, and archival fields separately.
  - Add tests that unexpected nested attributes cannot be assigned.
- **Status:** Open

### HIGH-005 — Private gig data remains in browser Cache Storage

- **Locations:**
  - `public/service-worker.js:76`
  - `public/service-worker.js:120`
- **Issue:** The service worker caches authenticated gig pages and API responses. Browser Cache Storage can retain this data after logout.
- **Impact:** A later user of the same browser profile may be able to recover private gig information.
- **Remediation:**
  - Set `Cache-Control: no-store` on authenticated HTML and API responses.
  - Clear gig caches on logout and active-band changes.
  - Restrict service-worker interception to explicitly marked offline-capable responses.
  - Add logout tests that inspect and clear Cache Storage.
- **Status:** Code fixed; authenticated responses use `no-store`, service-worker gig data is memory-only, and logout/band switching removes all service-worker Cache Storage

### HIGH-006 — Members can change security-sensitive band settings

- **Locations:**
  - `lib/routes/bands.rb:380`
  - `lib/routes/bands.rb:477`
  - `lib/routes/bands.rb:536`
- **Issue:** Any band member can modify band details, Google Calendar settings, public schedule settings, and public song settings.
- **Impact:** A regular member can expose data publicly, alter integrations, or disrupt the band without owner consent.
- **Remediation:**
  - Restrict public exposure, integration, membership, and destructive settings to owners or an explicit admin role.
  - Consider an audited approval process for public visibility changes.
- **Status:** Code fixed; vote and recommendation limits combine device ID and IP address, with aggregate per-band caps

## Medium Findings

### MEDIUM-001 — No Content-Security-Policy

- **Location:** `views/layout.erb:17`
- **Issue:** There is no CSP, and Flatpickr is loaded from a public CDN without subresource integrity.
- **Impact:** A compromised CDN or successful HTML injection has broad script execution opportunities.
- **Remediation:**
  - Self-host Flatpickr and other frontend dependencies.
  - Add a strict CSP with nonces or hashes.
  - Start in report-only mode, then enforce.
- **Status:** Code fixed; Flatpickr is self-hosted and script elements require a per-response nonce

### MEDIUM-002 — Incomplete security response headers

- **Location:** `config/nginx.conf:77`
- **Issue:** HSTS, frame denial, nosniff, and referrer policy are present, but CSP, `Permissions-Policy`, `Cross-Origin-Opener-Policy`, and `Cross-Origin-Embedder-Policy` are absent.
- **Remediation:** Add the missing headers and test behavior across public and authenticated pages.
- **Status:** Code fixed

### MEDIUM-003 — Public vote and recommendation rate limiting is weak

- **Locations:**
  - `lib/routes/public_songs.rb:76`
  - `lib/routes/public_songs.rb:123`
- **Issue:** Controls depend primarily on a device cookie that can be discarded or forged. IP address is stored but not used in the limit.
- **Impact:** Vote manipulation and recommendation spam remain feasible.
- **Remediation:**
  - Combine IP, device ID, fingerprint-resistant signals, and challenge/CAPTCHA thresholds.
  - Add per-band aggregate limits.
  - Add monitoring and the ability to temporarily disable public submissions.
- **Status:** Open

### MEDIUM-004 — Verbose OAuth diagnostics

- **Location:** `lib/services/oauth_service.rb`
- **Issue:** Debug output includes provider emails, user IDs, partial authorization codes/tokens, and account details.
- **Impact:** Sensitive personal data and authentication material can accumulate in logs.
- **Remediation:**
  - Replace `puts` debugging with structured logging.
  - Log opaque request IDs and status only.
  - Redact emails, UIDs, tokens, authorization codes, and secrets.
- **Status:** Open

### MEDIUM-005 — Logout is a GET request

- **Location:** `lib/routes/authentication.rb:62`
- **Issue:** Logout can be triggered by cross-site navigation, prefetching, or link scanners.
- **Impact:** Availability impact and unnecessary session churn; also conflicts with CSRF-safe mutation design.
- **Remediation:** Change logout to `POST`, require CSRF protection, and clear service-worker gig caches.
- **Status:** Open

## Positive Observations

- Band-scoped queries are generally implemented through `filter_by_current_band`, `user_bands`, and `find_user_gig`.
- No direct SQL injection from request parameters was identified; dynamic SQL fragments use constants or parameterized values.
- OAuth authorization-state validation is implemented in `lib/routes/oauth.rb:182`.
- Production checks require session and JWT secrets and enforce a minimum length.
- Public schedule endpoints conceal private events.

## Remediation Roadmap

### Phase 0 — Immediate

1. Remove password and secret logging.
2. Rotate potentially exposed secrets.
3. Remove external PostgreSQL and Valkey ports.
4. Enable CSRF protection.
5. Add server-side URL scheme validation.

### Phase 1 — High priority

1. Verify Apple identity tokens.
2. Require verified email or explicit linking for OAuth.
3. Implement revocable and rotating refresh tokens.
4. Harden session cookies and rotate session IDs.
5. Add login throttling and lockout.
6. Add parameter allowlists.
7. Restrict security-sensitive band settings to owners/admins.

### Phase 2 — Defense in depth

1. Add CSP and remaining security headers.
2. Prevent authenticated responses from entering persistent caches.
3. Clear service-worker caches on logout and band switching.
4. Strengthen public vote/recommendation abuse controls.
5. Redact OAuth diagnostics.
6. Change logout to a protected `POST` route.

## Regression Tests To Add

- Login request logs never contain the submitted password.
- State-changing browser routes reject requests without CSRF tokens.
- User-entered `javascript:`, `data:`, malformed, and hostless URLs are rejected.
- Apple ID tokens with invalid signatures, issuers, audiences, or expiry are rejected.
- OAuth cannot link to an existing account from an unverified email.
- Revoked refresh tokens cannot obtain access tokens.
- Password change and account deletion revoke existing tokens.
- Production session cookies are Secure, HttpOnly, and SameSite.
- Logout clears service-worker gig caches.
- Only owners/admins can change public visibility and integration settings.
- Cross-band ID tests continue to reject access to gigs, songs, venues, and practices.

## Dependency Validation

A Grype scan was attempted, but the sandbox could not download its vulnerability database. Run the following in an environment with network access:

```sh
bundle exec bundler-audit check --update
```

Add dependency auditing to CI and fail builds on known exploitable vulnerabilities.
