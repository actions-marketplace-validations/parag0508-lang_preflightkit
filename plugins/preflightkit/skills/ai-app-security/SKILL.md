---
name: ai-app-security
description: Design and review security for apps that use language models, such as chatbots, RAG and knowledge-base search, AI agents with tools, and MCP servers. Use when building or reviewing features that send user or document content to an LLM, let a model call tools or APIs, or retrieve private data for a model. Follows the OWASP Top 10 for LLM Applications.
---

# AI / LLM app security

Language-model features add risks that classic web security doesn't cover. The
core idea: **anything the model reads can steer the model.** That includes user
messages, web pages, files, emails, tool results and retrieved documents. So
treat model output as untrusted, and limit what the model is allowed to do.

Full guide with all ten risks: `references/ai-llm-apps.md`. Practices for code
written with AI assistants: `references/ai-assisted-development.md`.

## When designing a feature, answer these first
1. **What can the model read?** Mark which sources are untrusted (user input,
   the web, uploads, inbound email, third-party tool results).
2. **What can the model do?** List every tool and action, and its scope.
3. **Whose permissions does it use?** It should be the current user's, enforced
   in code, never a shared service account that can see everyone's data.
4. **Can data leave?** Outbound HTTP, email, rendered images or links, and file
   writes are all ways data can get out.

**Dangerous combination:** if one agent has (a) access to private data,
(b) exposure to untrusted content, and (c) a way to send data out, prompt
injection can steal data. Remove one of the three, or put a human approval step
in front of (c).

## Required controls
- [ ] Actions with side effects (send, pay, delete, publish, change permissions)
      need user confirmation, or a server-side permission check that doesn't
      depend on the model.
- [ ] Tools are narrowly scoped: read-only where possible, specific endpoints,
      one directory. Tool arguments are validated like public API input.
- [ ] Model output is escaped before rendering, validated against a schema before
      it's used, and **never** run as code, shell commands or raw SQL.
- [ ] Retrieval filters by user or tenant **inside the query** (metadata filter
      or separate index). Retrieved chunks never cross tenants.
- [ ] No secrets or authorization logic in prompts. Assume users can read the
      system prompt.
- [ ] Per-user rate limits, token caps, a maximum number of agent steps, and
      provider spending alerts.
- [ ] Models, MCP servers and plugins are pinned to versions and come from
      trusted sources. Third-party tool descriptions are reviewed.
- [ ] Every tool call is logged with the user, the arguments and the outcome.

## When reviewing existing code
Go through the controls above and report each gap with `file:line`, why it
matters (one sentence, no attack payloads), and the fix in code. Prioritize gaps
that let untrusted content trigger an action or leak another user's data.
