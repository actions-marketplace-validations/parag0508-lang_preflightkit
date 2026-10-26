# PreflightKit skills for Claude

Five skills that let Claude check your app is ready to ship while you build it.

| Skill | Command | What it does |
|-------|---------|--------------|
| **security-review** | `/preflightkit:security-review` | Full security review of your codebase: runs the scanner, traces risky data flows, and writes a prioritized report with `file:line` references and fixes |
| **secure-coding** | used automatically | Guardrails Claude follows whenever it writes queries, auth, uploads, shell calls or config |
| **dependency-vetting** | used automatically | Checks a package is real, maintained and not a typosquat before it's installed |
| **ai-app-security** | `/preflightkit:ai-app-security` | Security design and review for chatbots, RAG, agents and MCP servers (OWASP Top 10 for LLM Applications) |
| **preflight** | `/preflightkit:preflight` | GO / NO-GO scorecard before deploying, covering security, UI/UX and accessibility, database, performance and operations |

## Deploy gate (Claude Code)

The plugin also adds a hook that runs before Claude executes a shell command. If
the command deploys (`vercel --prod`, `netlify deploy --prod`, `fly deploy`,
`firebase deploy`, `wrangler deploy`, `railway up`, `gcloud ... deploy`,
`npm run deploy`, `git push` to main or master, and similar), it runs the
PreflightKit scanner first:

- **Blocking findings:** the deploy is stopped, and Claude is told what to fix.
- **A scanner could not run:** you're asked before the deploy goes ahead.
- **Clean:** the deploy runs as normal. A clean result is remembered until the
  code changes, so repeat deploys don't re-scan.

Other commands pass straight through. To change the behaviour, set an
environment variable (for example in `.claude/settings.json` under `"env"`):

| Variable | Values |
|---|---|
| `PREFLIGHTKIT_DEPLOY_GATE` | `block` (default), `ask` (ask you instead of stopping), `off` |
| `PREFLIGHTKIT_DEPLOY_ARGS` | Scanner options, e.g. `--audit-level=critical` or `--strict` |

The gate is only as thorough as the scanners installed on your machine. Run
`npx preflightkit doctor` to see which ones you have.

## Install

**Claude Code**
```
/plugin marketplace add parag0508-lang/preflightkit
/plugin install preflightkit@preflightkit
```
From a terminal (also where `/plugin` isn't available, such as the VS Code
extension):
```
claude plugin marketplace add parag0508-lang/preflightkit
claude plugin install preflightkit@preflightkit
```
Restart Claude Code afterwards. Add `--scope project` to both commands to
install it for everyone working on a repository (it's saved in
`.claude/settings.json`).

**Claude apps (claude.ai and desktop):** download a skill's zip from the
[Releases](https://github.com/parag0508-lang/preflightkit/releases) page, or build
the zips yourself with `./scripts/sync-plugin.sh --zip`. Then upload it under
**Settings → Features → Skills**. Custom skills need a Pro, Max, Team or
Enterprise plan with code execution turned on.

**Claude API:** upload a skill folder through the `/v1/skills` endpoint.

The skills only read your code and run local scanners. They never test systems
you don't own.
