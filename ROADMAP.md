# Roadmap

The aim is one trusted place that answers **"Is my app ready for real users?"**
Each pillar follows the same format as the security guides: **what goes wrong →
the fix → a check you can run.**

Status: ✅ available · 🚧 in progress · 📋 planned. Contributions are welcome on any 📋 item.

## Pillar 1: Security ✅
- ✅ OWASP Top 10 checklist, pre- and post-deploy
- ✅ Guides for PHP, Node.js, Python, Java/Spring, Go, Rails, .NET, React/Next.js
- ✅ Multi-language self-check script and CI workflow
- ✅ Security for AI-assisted development
- 📋 Guides for mobile (Android, iOS, Flutter, React Native), WordPress, Laravel, Kotlin and Rust
- ✅ **AI/LLM app security**: prompt injection, tool permissions, data leakage (OWASP Top 10 for LLM Applications)
- 📋 Cloud and container hardening (Docker, Kubernetes, AWS/GCP/Azure basics)

## Pillar 2: Performance 🚧
Core Web Vitals basics are in the [UI/UX checklist](./docs/ux-accessibility/). Still to come:
Core Web Vitals, image and asset budgets, caching layers, N+1 queries, load testing
(k6), and a Lighthouse CI recipe.

## Pillar 3: Accessibility and UI/UX ✅
Available in [docs/ux-accessibility/](./docs/ux-accessibility/). Covers:
A WCAG 2.2 AA checklist, keyboard and screen-reader testing, color contrast,
forms and error states, empty and loading states, and automated axe-core checks in CI.

## Pillar 4: Design and motion 🚧
Motion basics (reduced motion, durations, which properties to animate) are in the UI/UX checklist. Still to come:
Design-token basics, spacing and type scales, motion duration and easing tokens,
`prefers-reduced-motion` handling, and when animation helps or hurts.

## Pillar 5: Database ✅
Available in [docs/database/](./docs/database/). Covers:
Schema and index basics, safe migrations (zero-downtime patterns), backups with
tested restores, least-privilege database users, connection pooling, and keeping
personal data encrypted.

## Pillar 6: Stack selection 📋
Decision guides for picking a framework, database, hosting and auth provider, with
honest trade-offs, from a weekend project up to a large app.

## Pillar 7: Deploy and operate 📋
Environment and secrets management, CI/CD gates, logging and alerting, uptime
monitoring, incident runbooks, and rollback plans.

## Pillar 8: Privacy and compliance 📋
Practical baselines for GDPR, India's DPDP Act, CCPA, cookie consent, data
retention and deletion requests. This is guidance, not legal advice.

## Cross-cutting
- ✅ **Claude skills pack**: security review, secure coding, dependency vetting, AI app security and preflight ([plugins/preflightkit](./plugins/preflightkit/))
- ✅ Secure-coding rules for other assistants: `npx preflightkit rules` (AGENTS.md, Copilot, Cursor, Windsurf, CLAUDE.md)
- ✅ **Deploy gate**: the Claude Code plugin checks the project before Claude deploys
- 📋 SARIF output, so findings show up in GitHub code scanning
- 📋 A baseline file, to accept today's findings and fail only on new ones
- ✅ **CLI**: `npx preflightkit`, `doctor`, `init`, `rules` and `checklist`
- ✅ **GitHub Action**: `uses: parag0508-lang/preflightkit@v1`
- 📋 `pipx`, Homebrew and Docker distributions
- 📋 **Translations**: Hindi, Spanish, Portuguese, Indonesian, French, Japanese
  and others, so developers worldwide can use the toolkit in their own language
- 📋 A one-page web version of the checklist that you can work through and share
