# Security Checklist

Walk your app through this once before launch, and re-check after any major
change. Each item maps to a real class of attack. Mark `[x]` when done, and be
honest about `[ ]` — an unchecked box is a known risk, not a failure.

Items are grouped by the **OWASP Top 10** categories, plus a configuration and
operations section.

---

## 0. Before you start — know what you have

- [ ] You have an inventory of every app, service, and third-party component.
- [ ] You know which runtime versions you run (PHP, Node, Python, etc.) and whether they're still supported.
- [ ] You know which parts are internet-facing. These get priority on everything below.
- [ ] You have a way to patch fast (you've done it at least once and timed it).

## 1. Access control (A01: Broken Access Control)

- [ ] Every sensitive route checks authorization server-side, not just by hiding UI.
- [ ] Users can only access their own records (test by changing an ID in the URL — "IDOR").
- [ ] Admin functions require an admin role, verified on the server.
- [ ] Default-deny: new endpoints require auth unless explicitly made public.

## 2. Cryptography & secrets (A02: Cryptographic Failures)

- [ ] All traffic is HTTPS; HTTP redirects to HTTPS; HSTS is set.
- [ ] Passwords are hashed with bcrypt/argon2 (never MD5/SHA1, never plaintext).
- [ ] No secrets in source code. API keys, DB passwords, tokens live in env vars or a secrets manager.
- [ ] `.env`, config files, and backups are **not** web-accessible. (Try fetching `/.env` — it must 404.)
- [ ] Secret scanning has been run against the repo **and its git history**.

## 3. Injection (A03: Injection)

- [ ] All database queries use parameterized statements / prepared statements. No string concatenation of user input.
- [ ] Shell/command execution does not pass user input to `system()`, `exec()`, `eval()`, etc.
- [ ] Output is context-aware escaped to prevent XSS (HTML, JS, URL, attribute contexts).
- [ ] A Content-Security-Policy header is set.
- [ ] User-controlled data is never used to build file paths (path traversal).

## 4. Design (A04: Insecure Design)

- [ ] Rate limiting on login, password reset, and other abuse-prone endpoints.
- [ ] Account lockout / throttling against credential stuffing.
- [ ] Business logic can't be bypassed (e.g. negative quantities, skipped payment steps).

## 5. Misconfiguration (A05: Security Misconfiguration)

- [ ] Debug mode is OFF in production. No stack traces shown to users.
- [ ] Default/sample accounts and credentials are removed or changed.
- [ ] Directory listing is disabled on the web server.
- [ ] Only necessary ports/services are exposed.
- [ ] Security headers set: `X-Content-Type-Options`, `X-Frame-Options`/frame-ancestors, `Referrer-Policy`.

## 6. Vulnerable components (A06: Vulnerable & Outdated Components)

- [ ] Dependency audit run and clean: `composer audit`, `npm audit`, `pip-audit`, etc.
- [ ] Runtime is on a supported, patched version. (See [`docs/security/php.md`](./docs/security/php.md) for the PHP2Shell example, and [`docs/security/`](./docs/security/) for your stack.)
- [ ] Container base images scanned (Trivy/Grype) and rebuilt on CVE fixes.
- [ ] You subscribe to security advisories for your framework and major libs.

## 7. Authentication (A07: Identification & Authentication Failures)

- [ ] Strong password policy or passphrase support; checks against known-breached passwords.
- [ ] Multi-factor authentication available (and enforced for admins).
- [ ] Session tokens are random, HttpOnly, Secure, and SameSite; they expire and rotate on login.
- [ ] Password reset flow can't be used to enumerate accounts or take them over.

## 8. Data integrity (A08: Software & Data Integrity Failures)

- [ ] No deserialization of untrusted data (a classic RCE route).
- [ ] CI/CD pipeline and dependencies come from trusted, verified sources (lockfiles, checksums).
- [ ] Auto-update mechanisms verify signatures.

## 9. Logging & monitoring (A09: Logging & Monitoring Failures)

- [ ] Security-relevant events are logged (logins, failures, access-control denials, admin actions).
- [ ] Logs **don't** contain passwords, tokens, or full card/PII data.
- [ ] You'd actually notice an incident — alerts exist, not just log files nobody reads.

## 10. Server-side request forgery (A10: SSRF)

- [ ] User-supplied URLs are validated against an allowlist before the server fetches them.
- [ ] Internal metadata endpoints (e.g. cloud 169.254.169.254) are blocked from app-initiated requests.

---

## Configuration & operations

- [ ] Automated backups exist **and** a restore has actually been tested.
- [ ] Least-privilege: the DB user the app connects as can't drop tables it shouldn't.
- [ ] A documented, practiced patch/incident process (who does what when a critical CVE drops).
- [ ] File uploads: type/size validated, stored outside the web root, never executed.

## Priority order when something fails

1. Internet-facing + in CISA KEV (actively exploited) → **drop everything, fix now**.
2. Internet-facing + critical/high severity → fix this week.
3. Internal + exploitable → scheduled remediation.
4. Low severity / defense-in-depth → backlog.
