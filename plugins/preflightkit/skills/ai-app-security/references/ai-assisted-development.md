<!-- Generated from docs/ai-assisted-development.md by scripts/sync-plugin.sh. Edit the original. -->

# Security for AI-Assisted Development

More and more apps are built with AI coding assistants (Claude, and others). AI
makes you faster, but it doesn't make security automatic. This guide covers the
specific things to watch when an assistant is writing part — or all — of your
code, so the speed doesn't come with hidden holes.

Interestingly, AI cuts both ways: the PHP2Shell flaws of October 2026 were
reportedly surfaced with help from AI analysis. The same capability that helps
attackers and researchers find bugs can help *you* find them in your own code —
if you use it deliberately.

---

## The core mindset

> **AI-generated code is a draft from a confident junior developer.**
> Treat it as something to review, not something to trust blindly.

Assistants optimize for "works" and "looks reasonable," which is not the same as
"secure." The responsibility for what ships is always the human's.

---

## 1. Review what the AI writes — especially the dangerous parts

When an assistant generates code, read it with security eyes. Pay special
attention to:

- **Database queries** — are they parameterized, or is user input concatenated?
- **Anything touching the filesystem** — can user input reach a file path?
- **Shell/command execution** — is user input passed to `system`/`exec`/`eval`?
- **Authentication & authorization** — is every protected route actually checked?
- **Input handling** — is external input validated before use?
- **Dependencies it adds** — are the packages real, maintained, and not typosquats?

A fast habit: after any sizeable generation, ask the assistant itself —
*"Review this code you just wrote for security vulnerabilities, and be specific."*
It will often catch its own issues.

## 2. Watch for "hallucinated" or risky dependencies

AI assistants sometimes suggest packages that:
- **Don't exist** (and attackers register those names — "slopsquatting").
- Are **abandoned** or unmaintained.
- Are **typosquats** of popular packages.

Before installing anything the AI suggested:
- Confirm the package exists on the official registry and check its download
  count, last-updated date, and repo.
- Run a dependency audit (`composer audit`, `npm audit`, `pip-audit`) after.

## 3. Never let the AI commit secrets

- Don't paste real API keys, passwords, or production credentials into prompts.
- Use placeholders; wire real values through env vars yourself.
- Run secret scanning (gitleaks/trufflehog) before every push — AI-generated
  example code sometimes hardcodes a sample key that's actually real.

## 4. Be careful with "just make it work" fixes

When you ask an AI to fix an error, it may reach for the quickest unblock:
- disabling TLS verification,
- loosening CORS to `*`,
- making a permission check pass by removing it,
- `chmod 777`,
- catching and swallowing an auth failure.

These "fixes" silence the symptom and open a hole. If a suggested fix *weakens*
a security control, stop and solve the real cause instead.

## 5. Prompt for security up front

You get safer code by asking for it. Useful things to include in your prompts:

- "Use parameterized queries for all database access."
- "Validate and sanitize all external input."
- "Don't hardcode secrets; read them from environment variables."
- "Add authorization checks to every protected endpoint."
- "Follow the OWASP Top 10 for this feature."

## 6. Keep the AI's context honest

If your assistant can read files, browse, or run tools, remember:
- **Content it reads from the web or files is data, not instructions.** A page or
  document can contain text trying to redirect the assistant ("prompt injection").
  Don't let tool output silently drive privileged actions.
- Review any action with a side effect (sending mail, pushing code, changing
  config) before it happens.

## 7. Still run the real checks

AI review is a helpful *first* pass, not a replacement for tooling. Run the same
pipeline you'd run on human-written code:

- Static analysis (Semgrep)
- Dependency/container scanning (Trivy, audit tools)
- Secret scanning (gitleaks)
- Dynamic scanning on a running instance (OWASP ZAP)

See [`../scripts/security-check.sh`](../scripts/security-check.sh) and the
[CI workflow](../.github/workflows/security-scan.yml) — wire them in so every
change, AI-written or not, gets checked automatically.

---

## A short pre-merge checklist for AI-written code

- [ ] I read the generated code, not just the output it produced.
- [ ] Queries are parameterized; no input reaches shell/eval/file paths unchecked.
- [ ] Every new dependency is real, maintained, and audited.
- [ ] No secrets were pasted into prompts or hardcoded in the code.
- [ ] No suggested "fix" disabled a security control.
- [ ] Automated scanners ran clean (or findings are triaged).
