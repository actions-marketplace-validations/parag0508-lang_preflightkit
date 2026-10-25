# PreflightKit

**Is your app ready to ship? Check it in 5 minutes.**

A free, open checklist and scanner kit that catches the security mistakes
attackers actually exploit. It works with every major framework, before and after
you deploy, and it's built with AI-assisted development in mind (Claude, Copilot,
Cursor and others).

```bash
git clone https://github.com/parag0508-lang/preflightkit
./preflightkit/scripts/security-check.sh /path/to/your/project
```

> **Defensive use only.** Use this toolkit on apps you own or are authorized to
> work on. It reads your code. It doesn't attack anything.

---

## Why you need this (in one example)

On **21 October 2026**, the PHP team rushed out emergency patches for two critical
flaws in PHP itself, **CVE-2026-109618** and **CVE-2026-109619** ("PHP2Shell",
CVSS 9.2). They let anyone run code on a server without logging in, through
PHP-FPM, mod_php, php-cgi, FrankenPHP and LiteSpeed. Details leaked a day early,
so teams that knew their versions and could patch quickly were safe. Many others
scrambled.

Most breaches aren't exotic. They come from a short list of known mistakes:
outdated runtimes, injection, leaked secrets, weak auth and vulnerable
dependencies. This toolkit helps you close that list systematically.

---

## What you get

| | What it does | Start here |
|---|---|---|
| ✅ **Checklist** | Pre- and post-deploy checks mapped to the OWASP Top 10 | [SECURITY-CHECKLIST.md](./SECURITY-CHECKLIST.md) |
| 🧩 **Framework guides** | Top risks, the fix in code, and a copy-paste self-check for 8 stacks | [docs/security/](./docs/security/) |
| 🤖 **AI-built apps** | What to review when an assistant wrote the code | [ai-assisted-development.md](./docs/ai-assisted-development.md) |
| 🧠 **AI/LLM app security** | Prompt injection, agent and tool permissions, RAG data leaks (OWASP LLM Top 10) | [ai-llm-apps.md](./docs/security/ai-llm-apps.md) |
| ♿ **UI/UX & accessibility** | WCAG 2.2 AA, UX states, motion, Core Web Vitals | [docs/ux-accessibility/](./docs/ux-accessibility/) |
| 🗄️ **Database** | Exposure, least privilege, tested backups, safe migrations, performance | [docs/database/](./docs/database/) |
| ⚡ **Self-check script** | Runs free scanners and flags dangerous patterns across 7 languages | [scripts/security-check.sh](./scripts/security-check.sh) |
| 🔁 **CI workflow** | Scans every push and pull request automatically | [security-scan.yml](./.github/workflows/security-scan.yml) |

### Supported stacks

PHP (Laravel, Symfony, WordPress) · Node.js (Express, Fastify, NestJS) ·
Python (Django, Flask, FastAPI) · Java (Spring Boot) · Go · Ruby on Rails ·
.NET (ASP.NET Core) · React / Next.js / Vue

---

## Use it in 3 steps

1. **Run the script** on your project. It detects your stack and runs whichever
   free scanners you have installed. It tells you what to install for the rest.
2. **Walk the checklist** once and fix anything you can't tick.
3. **Copy the CI workflow** into `.github/workflows/` so every future change gets
   checked automatically.

Fix by real risk, not alphabetically: anything internet-facing that appears in
[CISA's Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
comes first.

## Free tools it uses

[Semgrep](https://semgrep.dev) (code) · [Trivy](https://trivy.dev) (dependencies,
containers, misconfiguration) · [gitleaks](https://github.com/gitleaks/gitleaks)
(secrets) · [OWASP ZAP](https://www.zaproxy.org) (running apps) · native auditors
(`composer audit`, `npm audit`, `pip-audit`, `govulncheck`, `brakeman`,
`bundle-audit`, `dotnet list package --vulnerable`)

---

## Where this is going

PreflightKit is growing into **a ship-readiness kit for production apps**. Security,
UI/UX and accessibility, and databases are available now. Performance, design
systems, deployment and privacy come next, along with ready-made skills for AI
coding assistants. See the [ROADMAP](./ROADMAP.md) and pick something to help with.

## Contributing

New framework guides, corrections and translations are very welcome. See
[CONTRIBUTING.md](./CONTRIBUTING.md). Found a security problem in the toolkit
itself? See [SECURITY.md](./SECURITY.md).

## License

[MIT](./LICENSE). Free to use, copy and adapt, including commercially.
