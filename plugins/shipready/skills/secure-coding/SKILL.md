---
name: secure-coding
description: Guardrails for writing secure code while building features. Use whenever writing or changing code that touches database queries, authentication, sessions, authorization, file uploads or paths, shell commands, HTML rendering, outbound HTTP requests, secrets or configuration, or deserialization, in any language or framework.
---

# Secure coding guardrails

Apply these rules to every piece of code you write or change. They're defaults,
not suggestions. If the user asks for something that breaks one, say which rule
and why, then offer the safe version.

## Rules by risk

**Database**
- Always use parameterized queries or the ORM's safe API. Never build SQL by
  string concatenation or interpolation with user data.
- For column or sort names taken from input, check them against an allowlist.

**Commands and code execution**
- Don't call a shell with user input. Use argument-array APIs
  (`execFile`, `subprocess.run([...])`, `exec.Command(name, args...)`).
- Never `eval`, `new Function`, `unserialize`, `pickle.loads`, `yaml.load`,
  `Marshal.load` or `BinaryFormatter` on untrusted data. Use JSON and safe loaders.

**Access control**
- Every new endpoint, route handler or server action requires authentication
  unless the user explicitly says it's public.
- Check that the current user may access **this specific record** (ownership or
  role) on the server, not just that they're logged in.

**Output**
- Rely on the framework's auto-escaping. Flag any use of
  `dangerouslySetInnerHTML`, `v-html`, `|safe`, `html_safe` or `raw`, and
  sanitize with DOMPurify or similar if raw HTML is truly needed.
- Validate URLs before putting them in `href` or redirects (block `javascript:`
  and open redirects).

**Files and network**
- Resolve file paths and confirm they stay inside the intended base directory.
- Uploads: check content type and size, store outside the web root, never execute.
- Server-side fetches of user-supplied URLs: allowlist the destinations, and block
  private and metadata IP ranges.

**Secrets and configuration**
- Read secrets from environment variables or a secrets manager. Never hardcode
  them. Use placeholders in examples.
- Never put secrets in variables that frontend builds expose (`NEXT_PUBLIC_*`,
  `VITE_*`, `REACT_APP_*`).
- Production defaults: debug off, generic error pages, restrictive CORS (no `*`
  with credentials), security headers on.

**Authentication**
- Hash passwords with argon2id or bcrypt. Generate tokens with a cryptographically
  secure random generator.
- Cookies: `HttpOnly`, `Secure`, `SameSite=Lax` (or `Strict`). Rotate the session on login.
- When verifying JWTs, pin the allowed algorithms and check expiry.

**Model output (AI features)**
- Treat model output as untrusted input. Escape it, validate it, never run it.
- Tools an AI agent calls act with the **user's** permissions, and actions with
  side effects need a confirmation step.

## Never "fix" an error by weakening security
If the quickest fix for a failing build or request is to disable TLS
verification, widen CORS to `*`, remove an auth check, `chmod 777`, or silence
a validation error, **stop**. Find the real cause, or explain the trade-off to
the user and let them decide.

## Before you finish
Re-read what you wrote and check it against the rules above. Briefly tell the
user about any security decision you made (for example, "added an ownership check
on GET /orders/:id").
