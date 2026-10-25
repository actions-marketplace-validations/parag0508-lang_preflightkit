# Changelog

## 1.1.0

Based on feedback from running PreflightKit on a real Next.js project.

### Added
- **Monorepo support.** Every folder with a lockfile or manifest, up to three
  levels down (`apps/web`, `packages/api`, ...), gets its own dependency audit.
  `node_modules`, tests and paths in `.preflightkitignore` are skipped.
- **Deploy gate for Claude Code.** The plugin checks the project before Claude
  runs a deploy command (`vercel --prod`, `git push` to main, `fly deploy`,
  `npm run deploy` and others) and stops it when something is blocking.
- **`npx preflightkit rules`** writes the secure-coding rules for AGENTS.md,
  GitHub Copilot, Cursor, Windsurf and CLAUDE.md.
- **`npx preflightkit doctor`** shows which scanners are installed and how to
  install the rest.
- **`--audit-level`** (default `high`) and **`--include-dev`**: dependency
  vulnerabilities below the level are advisory, and dev dependencies are
  skipped unless asked for.
- **Accepting reviewed findings:** a `preflightkit-ignore` comment on or above
  the line, or paths in `.preflightkitignore`. `.gitleaksignore` and
  `.trivyignore` in the project folder are picked up too.
- **Pull request annotations** for risky lines, and `blocking`, `warnings` and
  `errors` outputs on the GitHub Action.
- Action inputs `fail-on` (`findings`, `warnings`, `never`), `audit-level`
  and `include-dev`.
- The workflow template explains how to block deploys until the check passes.

### Changed
- Results are now **blocking** (secrets, vulnerabilities at or above the audit
  level), **advisory** (risky patterns, Semgrep) or **scanner error**. Only
  blocking findings and scanner errors fail the build by default.
- Exit codes: `0` nothing blocking, `1` blocking findings, `2` a scanner could
  not run.
- The pattern check skips test files, obvious placeholder secrets and
  `dangerouslySetInnerHTML` fed by `JSON.stringify(...)`.
- On Windows, the CLI finds Git Bash even when it isn't on PATH.
- The skills explain the new result kinds, and never silence a finding without
  the user's agreement.

### Fixed
- A crashed auditor (for example npm's `EALLOWSCRIPTS`) was reported as
  "flagged packages". It's now reported as "could not run".
- `pip-audit` audited the current Python environment instead of the project.
- `yarn npm audit` fell back to the Yarn 1 command when it found
  vulnerabilities.

### Deprecated
- The `fail-on-warnings` action input. `true` still means "fail on any
  warning" (`fail-on: warnings`) and `false` means `fail-on: never`.

## 1.0.0

First release: security checklist, framework guides, scanner script, CLI,
GitHub Action and Claude skills.
