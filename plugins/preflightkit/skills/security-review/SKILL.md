---
name: security-review
description: Run a full security review of the user's own codebase and produce a prioritized report with file and line references and concrete fixes. Use when the user asks to review, audit or security-check their app or repo, asks whether it's safe or ready to deploy, or asks "what vulnerabilities does my code have". Covers PHP, Node.js, Python, Java, Go, Rails, .NET, frontend and AI/LLM apps.
---

# Security review

Review the user's own code for the vulnerabilities attackers actually exploit,
then hand back a report they can act on.

## Ground rules
- **Only review code the user owns or is authorized to work on.** This skill
  reads code and runs local scanners. It never probes, scans or attacks a live
  system the user hasn't confirmed is theirs.
- **Report fixes, not exploits.** Explain why something is exploitable in one
  sentence. Never write working attack payloads.
- **Be honest about confidence.** Mark each finding *confirmed* (you traced the
  data flow) or *likely* (pattern match, not traced). List what you didn't check.

## Steps

1. **Identify the stack.** Look for `composer.json`, `package.json`,
   `requirements.txt`/`pyproject.toml`, `pom.xml`/`build.gradle`, `go.mod`,
   `Gemfile`, `*.csproj`, plus framework markers (Next.js, Django, Laravel,
   Spring Boot). Note which parts are internet-facing.

2. **Run the scanner** bundled with this skill on the project root:
   ```bash
   bash scripts/security-check.sh <project-path>
   ```
   (`scripts/` is inside this skill's directory.) It runs whichever free tools are
   installed (gitleaks, Semgrep, Trivy, native dependency auditors) and greps for
   dangerous patterns. If tools are missing, say which ones and carry on. The
   manual review below is still worth doing.

3. **Read the references for this stack**: `references/checklist.md` (OWASP Top
   10), plus the matching file in `references/stacks/` (for example
   `nodejs.md`, `php.md`, or `ai-llm-apps.md` if the app calls a language model).

4. **Review by hand, in this order** (highest impact first):
   1. **Untrusted input → dangerous sinks.** Trace request params, bodies,
      headers, uploaded files and model output into SQL, shell, `eval`,
      deserialization, file paths, templates, outbound HTTP (SSRF) and HTML output.
   2. **Access control.** Every route, API handler and server action: is
      authentication checked? Does the code check the user **owns** the object
      it's asked for (IDOR)? Are admin actions verified on the server?
   3. **Secrets.** Hardcoded keys, committed `.env` files, secrets in frontend
      bundles (`NEXT_PUBLIC_`, `VITE_`), secrets in logs.
   4. **Authentication and sessions.** Password hashing, JWT verification, cookie
      flags, rate limiting on login and reset.
   5. **Configuration.** Debug mode, CORS, security headers, exposed admin or
      actuator endpoints, permissive file upload handling.
   6. **Dependencies and runtime.** Outdated or end-of-life runtime versions,
      flagged packages. Anything in CISA's Known Exploited Vulnerabilities
      catalog is top priority.

5. **Write the report** in the format below.

## Report format

````markdown
# Security review: <project> (<date>)

**Summary:** <2–3 sentences: overall state, the single most urgent fix>

| # | Severity | Issue | Location | Confidence |
|---|----------|-------|----------|------------|
| 1 | Critical | SQL injection in user search | src/users.php:42 | Confirmed |

## 1. <Issue title>  (Critical)
**Where:** `path/to/file.ext:line`
**Why it matters:** <one sentence on impact, no payloads>
**Fix:**
```<lang>
<corrected code>
```

## What I checked / didn't check
- Scanners run: …   Missing tools: …
- Not reviewed: … (e.g. infrastructure, the live deployment)
````

**Severity:** *Critical*: remote code execution, auth bypass, or a mass data
leak reachable from the internet. *High*: an exploitable injection or IDOR, or
exposed secrets. *Medium*: needs extra conditions, or is a defense-in-depth gap
on a sensitive path. *Low*: hardening and hygiene.

Order findings by severity, then by whether they're internet-facing. Offer to fix
the top issues directly, one at a time, and show each diff.
