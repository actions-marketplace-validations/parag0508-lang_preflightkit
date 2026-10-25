# PreflightKit skills for Claude

Five skills that let Claude check your app is ready to ship while you build it.

| Skill | Command | What it does |
|-------|---------|--------------|
| **security-review** | `/preflightkit:security-review` | Full security review of your codebase: runs the scanner, traces risky data flows, and writes a prioritized report with `file:line` references and fixes |
| **secure-coding** | used automatically | Guardrails Claude follows whenever it writes queries, auth, uploads, shell calls or config |
| **dependency-vetting** | used automatically | Checks a package is real, maintained and not a typosquat before it's installed |
| **ai-app-security** | `/preflightkit:ai-app-security` | Security design and review for chatbots, RAG, agents and MCP servers (OWASP Top 10 for LLM Applications) |
| **preflight** | `/preflightkit:preflight` | GO / NO-GO scorecard before deploying, covering security, UI/UX and accessibility, database, performance and operations |

## Install

**Claude Code**
```
/plugin install preflightkit --marketplace parag0508-lang/preflightkit
```
Or in two steps:
```
/plugin marketplace add parag0508-lang/preflightkit
/plugin install preflightkit@preflightkit
```

**Claude apps (claude.ai and desktop):** download a skill's zip from the
[Releases](https://github.com/parag0508-lang/preflightkit/releases) page, or build
the zips yourself with `./scripts/sync-plugin.sh --zip`. Then upload it under
**Settings → Features → Skills**. Custom skills need a Pro, Max, Team or
Enterprise plan with code execution turned on.

**Claude API:** upload a skill folder through the `/v1/skills` endpoint.

The skills only read your code and run local scanners. They never test systems
you don't own.
