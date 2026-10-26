---
name: preflight
description: Pre-deploy ship-readiness check that gives a go or no-go scorecard across security, UI/UX and accessibility, database, performance and operations. Use when the user asks whether their app is ready to launch, deploy or go to production, wants a launch checklist, or says they're about to ship.
---

# Preflight: is this app ready to ship?

Give the user a clear **GO / GO WITH RISKS / NO-GO** verdict, backed by evidence
from their code and config, plus the short list of things to fix first.

References in this skill's directory:
`references/security-checklist.md`, `references/ux-accessibility.md`,
`references/database.md`. Scanner: `scripts/security-check.sh`.

## Steps

1. **Understand the app.** What's the stack? Where is it deployed? Who uses it
   (public, internal, paying customers)? Does it handle personal or payment data?
   Ask the user only for what you can't find in the repo.

2. **Security** (blockers live here most often):
   - Run `bash scripts/security-check.sh <project-path>`. `[fail]` results are
     blocking, `[warn]` are advisory (verify before counting them), and
     `[error]` means that scanner didn't run: put it under "Not checked".
   - Check that the runtime and framework versions are supported and patched.
   - Spot-check the highest-risk items in `references/security-checklist.md`:
     authorization on sensitive routes, secrets out of the repo, debug off,
     parameterized queries, `.env` not served.

3. **UI/UX and accessibility:**
   - If the app runs locally, run `npx @axe-core/cli <url>` and
     `npx lighthouse <url> --only-categories=accessibility,performance` on the
     main pages.
   - Check the code for: labels on inputs, native buttons and links, loading,
     empty and error states, and `prefers-reduced-motion` handling.

4. **Database:** check migrations are in version control and there's a backup
   and restore story. Confirm the app's database user isn't an admin, and that
   the database isn't publicly reachable (ask if this is infrastructure you can't see).

5. **Operations:** error tracking or logging in place, health check endpoint, a
   way to roll back, environment variables documented, and someone who gets
   alerted when the app breaks.

## Verdict rules
- **NO-GO** if any of these is true: a critical security finding (remote code
  execution, auth bypass, exposed secrets, SQL injection on a public route), an
  unresolved `[fail]` from the scanner, the
  runtime is end-of-life and internet-facing, no backups for production data, or
  debug mode is on in production.
- **GO WITH RISKS** if there are high or medium issues with a clear plan and date
  to fix them.
- **GO** otherwise.

## Output

```markdown
# Preflight: <app> → **NO-GO** / **GO WITH RISKS** / **GO**

| Area | Status | Notes |
|------|--------|-------|
| Security | 🔴 / 🟡 / 🟢 | … |
| UI/UX & accessibility | … | … |
| Database | … | … |
| Performance | … | … |
| Operations | … | … |

## Fix before launch
1. … (file:line, the fix)

## Fix in the first week
…

## Not checked
… (anything you couldn't verify from here)
```
Keep the lists short and ordered by risk. Offer to fix the blockers, one at a
time, re-running the scanner after each. Never clear a blocker by adding an
ignore comment or lowering the audit level unless the user explicitly decides to
accept that risk.

To make this check automatic, the PreflightKit plugin also stops deploy commands
(`vercel --prod`, `git push` to main and similar) when the scanner finds
something blocking. Tell the user what blocked it and how to fix it.
