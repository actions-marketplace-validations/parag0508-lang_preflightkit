# Security Guides by Framework

Start with the universal [SECURITY-CHECKLIST](../../SECURITY-CHECKLIST.md), then open
the guide for your stack. Each guide has the same structure: **top risks → the
fix in code → a copy-paste self-check.**

| Stack | Guide | Native audit tools |
|-------|-------|--------------------|
| PHP (Laravel, Symfony, WordPress) | [php.md](./php.md) | `composer audit` |
| Node.js (Express, Fastify, NestJS) | [nodejs.md](./nodejs.md) | `npm audit` |
| Python (Django, Flask, FastAPI) | [python.md](./python.md) | `pip-audit`, `bandit` |
| Java (Spring Boot) | [java-spring.md](./java-spring.md) | OWASP Dependency-Check |
| Go | [go.md](./go.md) | `govulncheck`, `gosec` |
| Ruby on Rails | [ruby-rails.md](./ruby-rails.md) | `brakeman`, `bundle-audit` |
| .NET (ASP.NET Core) | [dotnet.md](./dotnet.md) | `dotnet list package --vulnerable` |
| Frontend (React, Next.js, Vue) | [frontend-react-nextjs.md](./frontend-react-nextjs.md) | `npm audit` |
| **AI / LLM apps** (chatbots, RAG, agents, MCP) | [ai-llm-apps.md](./ai-llm-apps.md) | OWASP Top 10 for LLM Applications |

Tools that work across every stack: **Semgrep** (code), **Trivy** (dependencies,
containers, misconfiguration), **gitleaks** (secrets), and **OWASP ZAP** (a running app).

Missing your stack? See [CONTRIBUTING](../../CONTRIBUTING.md). New guides should
follow the same three-part structure.
