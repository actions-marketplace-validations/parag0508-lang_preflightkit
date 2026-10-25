# PreflightKit

**Is your app ready to ship? Check it in 5 minutes.**

A free, open toolkit that catches the security mistakes attackers actually
exploit, plus the UX, accessibility and database gaps that break launches. It
works with every major framework, before and after you deploy, and it's built for
apps written with AI assistants (Claude, Copilot, Cursor and others).

**What makes it different**

- 🛑 **Stops risky deploys, even when an AI is deploying.** The Claude Code plugin
  checks the project before Claude runs `vercel --prod`, `git push` to main or
  another deploy command, and stops it if something is blocking.
- 🤖 **Teaches your AI assistant to write safer code.** One command gives Claude,
  Copilot, Cursor, Codex and Windsurf the same secure-coding rules.
- 🎯 **Fails only on what matters.** Leaked secrets and serious vulnerabilities
  block. Risky patterns are shown as advice, never as a wall of red builds.
- 🧾 **Honest results.** A scanner that crashes is reported as "not checked",
  never as "vulnerabilities found" or "clean".
- 🆓 **Free scanners, one command, every stack:** gitleaks, Semgrep, Trivy and the
  native auditors for PHP, Node, Python, Java, Go, Ruby and .NET.

## Quick start: pick one

**1. Check a project now** (Node 18+ and bash; on Windows it uses Git Bash from Git for Windows, from any terminal)
```bash
npx preflightkit            # scan the current folder
npx preflightkit doctor     # see which scanners you have, and how to add the rest
npx preflightkit init       # add the GitHub Actions check to this repo
npx preflightkit rules      # give your AI assistant the secure-coding rules
npx preflightkit pre-commit # refuse commits that contain secrets
```

**2. Check every push and pull request:** add this step to a GitHub Actions workflow
```yaml
- uses: parag0508-lang/preflightkit@v1
```
It sets up gitleaks, Semgrep and Trivy, scans, writes a summary on the run
page and annotates risky lines in the pull request. See the
[full workflow](./templates/preflightkit.yml) and [tuning the check](#tuning-the-check).

**3. Let Claude check as you build** (Claude Code)
```
/plugin install preflightkit --marketplace parag0508-lang/preflightkit
```
Then ask for `/preflightkit:security-review` or `/preflightkit:preflight`.
From then on, deploy commands Claude runs are checked first.
[More about the skills](./plugins/preflightkit/), including how to use them in
the Claude apps.

**4. No install:** clone the repo and run the script
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
| 🧩 **Framework guides** | Top risks, the fix in code, and a copy-paste self-check for 8 stacks plus AI/LLM apps | [docs/security/](./docs/security/) |
| 🤖 **AI-built apps** | What to review when an assistant wrote the code | [ai-assisted-development.md](./docs/ai-assisted-development.md) |
| 🧠 **AI/LLM app security** | Prompt injection, agent and tool permissions, RAG data leaks (OWASP LLM Top 10) | [ai-llm-apps.md](./docs/security/ai-llm-apps.md) |
| ♿ **UI/UX & accessibility** | WCAG 2.2 AA, UX states, motion, Core Web Vitals | [docs/ux-accessibility/](./docs/ux-accessibility/) |
| 🗄️ **Database** | Exposure, least privilege, tested backups, safe migrations, performance | [docs/database/](./docs/database/) |
| ⚡ **Scanner + CLI** | Runs free scanners and flags dangerous patterns across 7 languages | `npx preflightkit` · [script](./scripts/security-check.sh) |
| 🔁 **GitHub Action** | Checks every push and pull request, with a summary on the run page | [action.yml](./action.yml) · [workflow](./templates/preflightkit.yml) |
| 🤖 **Claude skills** | Security review, secure-coding guardrails, dependency vetting, AI app security, GO/NO-GO preflight | [plugins/preflightkit/](./plugins/preflightkit/) |

### Supported stacks

PHP (Laravel, Symfony, WordPress) · Node.js (Express, Fastify, NestJS) ·
Python (Django, Flask, FastAPI) · Java (Spring Boot) · Go · Ruby on Rails ·
.NET (ASP.NET Core) · React / Next.js / Vue

---

## Use it in 3 steps

1. **Run the check** (`npx preflightkit`). It detects your stack and runs whichever
   free scanners you have installed, and tells you what to install for the rest.
2. **Walk the checklist** once and fix anything you can't tick.
3. **Turn on the Action** (`npx preflightkit init`) so every future change is
   checked automatically.

Fix by real risk, not alphabetically: anything internet-facing that appears in
[CISA's Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
comes first.

## Block deploys until the check passes

| How you deploy | What to do |
|---|---|
| Claude Code runs the deploy | Install the plugin (step 3). Deploy commands are checked first and stopped on blocking findings. |
| From a GitHub Actions job | Give the deploy job `needs: preflight`. The [workflow template](./templates/preflightkit.yml) has an example. |
| Your host deploys on merge (Vercel, Netlify, Render, Hostinger...) | Settings → Rules → Rulesets: require the **Ship-readiness security check** status on `main`. |
| Before code even leaves your machine | `npx preflightkit pre-commit` refuses commits containing secrets (uses gitleaks; works with Husky). |
| From your own terminal | Run `npx preflightkit` first. It exits non-zero when something blocks, so `npx preflightkit && ./deploy.sh` works. |

## Use it with any AI coding assistant

```bash
npx preflightkit rules            # AGENTS.md, Copilot and Cursor
npx preflightkit rules --all      # also CLAUDE.md and Windsurf
```

This writes PreflightKit's secure-coding rules (parameterized queries, no shell
with user input, ownership checks, no hardcoded secrets, never "fixing" a
scanner by silencing it, and more) to the files each assistant reads:

| Assistant | File |
|---|---|
| Codex, Cursor, GitHub Copilot coding agent and others | `AGENTS.md` |
| GitHub Copilot in the editor | `.github/copilot-instructions.md` |
| Cursor | `.cursor/rules/preflightkit.mdc` |
| Claude Code (without the plugin) | `CLAUDE.md` (`--claude`) |
| Windsurf | `.windsurf/rules/preflightkit.md` (`--windsurf`) |

Your own content in those files is kept: PreflightKit only manages the section
between its markers, and re-running updates it in place.

## Tuning the check

Every result is one of three kinds, so a noisy heuristic can't block a release:

| Result | What counts | Fails the build? |
|---|---|---|
| **blocking** `[fail]` | Leaked secrets; dependency vulnerabilities at or above the audit level; Trivy findings at or above it | Yes |
| **advisory** `[warn]` | Risky code patterns, Semgrep findings, dependency vulnerabilities below the audit level | Only with `--strict` / `fail-on: warnings` |
| **scanner error** `[error]` | A scanner is installed but crashed, so nothing was checked (reported as an error, never as "vulnerabilities found") | Yes, unless `fail-on: never` |

Exit codes: `0` nothing blocking, `1` blocking findings, `2` a scanner could not run.

**Monorepos** work out of the box: every folder with a lockfile or manifest, up
to three levels down (`apps/web`, `packages/api`...), gets its own dependency
audit, labelled with its path.

| CLI option | Action input | Default | Meaning |
|---|---|---|---|
| `--audit-level=LEVEL` | `audit-level` | `high` | Lowest dependency severity that blocks: `low`, `moderate`, `high`, `critical` |
| `--include-dev` | `include-dev` | off | Also audit development dependencies (production only by default) |
| `--strict` | `fail-on: warnings` | off | Advisory findings block too |
| | `fail-on` | `findings` | `findings`, `warnings` or `never` (report only) |

`fail-on-warnings` from earlier versions still works but is deprecated:
`true` means `fail-on: warnings`, `false` means `fail-on: never`.

**Accepting a reviewed finding.** The pattern check skips test files (`*.test.*`,
`*.spec.*`, `tests/`, `__tests__/` and similar), obvious placeholder secrets, and
`dangerouslySetInnerHTML` fed by `JSON.stringify(...)`. For anything else:

```js
// preflightkit-ignore: cache key, not a security use of MD5
const key = md5(slug);
```

The marker works on the flagged line or the line above. To skip whole paths, add a
`.preflightkitignore` at the project root (one path or glob per line, `#` for
comments). It applies to the pattern check, Semgrep and Trivy. Each scanner's own
mechanism works too: `gitleaks:allow` comments or `.gitleaksignore`, `nosemgrep`
comments, and `.trivyignore` for specific CVEs.

> **Tip:** with `JSON.stringify` inside a `<script>` tag, escape `<` as well
> (`.replace(/</g, '\\u003c')`) so data can't close the tag.

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
