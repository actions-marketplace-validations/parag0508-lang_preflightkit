# Security for AI / LLM Apps (chatbots, RAG, agents, MCP servers)

If your app **sends user content to a language model**, or lets a model **call
tools**, it has a class of risks that classic web security doesn't cover. This
guide follows the
[OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/)
and turns each risk into concrete defenses.

> One rule covers most of this guide: **anything the model reads can steer the
> model.** That includes user messages, web pages, PDFs, emails, tool results and
> retrieved documents. Treat model output as untrusted input, and limit what the
> model is allowed to do, the same way you'd limit an untrusted user.

---

## 1. Prompt injection (LLM01)
Text inside content the model processes can override your instructions. This
works directly ("ignore previous instructions") and indirectly, through text
hidden in a document, web page or email the model reads.

You can't reliably filter this out of the input, so design for it instead:
- **Least privilege:** the model can only do what you'd let an anonymous user do,
  unless a real user's permissions are checked on the server for every action.
- **Human confirmation** for anything with side effects: sending, paying,
  deleting, publishing or changing permissions.
- **Keep trusted and untrusted content separate** in prompts, and label the
  untrusted parts clearly. This helps, but it isn't a guarantee.
- **Don't combine three things in one agent:** access to private data, exposure
  to untrusted content, and the ability to send data out (for example, web
  requests, email, or rendering images from URLs). If an agent needs all three,
  add a human checkpoint.

## 2. Sensitive information disclosure (LLM02)
- Don't put secrets, API keys or other users' data in prompts or system prompts.
- Enforce data access **in your retrieval layer**, before anything reaches the
  model. Never write "the model will only answer about this user's data" in a
  prompt and rely on it.
- Scrub personal data from logs, traces and evaluation datasets.

## 3. Supply chain (LLM03)
Models, datasets, LoRA adapters, prompt templates, MCP servers and agent plugins
are all dependencies. Pin their versions, get them from trusted publishers, and
review what a third-party MCP server or plugin can access before installing it.

## 4. Data and model poisoning (LLM04)
If you fine-tune your model or index content into a knowledge base, control who
can add documents to it. A single poisoned document can be retrieved into many
users' conversations.

## 5. Improper output handling (LLM05)
Model output is untrusted input to whatever runs next:
- Escape it before rendering as HTML, to prevent XSS. Be careful with Markdown
  images and links, which can carry data out of the page.
- **Never** run model output with `eval`, a shell, or SQL. If the model produces
  queries, use read-only database credentials, an allowlist of operations, and
  parameterized templates.
- Validate structured output (JSON) against a schema before acting on it.

## 6. Excessive agency (LLM06)
- Give each tool the **narrowest scope** possible: read-only where it can be,
  one directory rather than the whole filesystem, specific API endpoints rather
  than a general HTTP client.
- Use **the user's own credentials and permissions**, not a powerful service
  account that every user's session shares.
- Cap the number of agent steps, how much it can spend, and the time it can run.

## 7. System prompt leakage (LLM07)
Assume users can extract your system prompt. Never put secrets or the only copy
of an authorization rule there. Enforce permissions in code.

## 8. Vector and embedding weaknesses (LLM08)
In multi-tenant retrieval, filter by tenant or user **in the vector query
itself** (a metadata filter or separate index), so one customer's documents can
never be retrieved for another.

## 9. Misinformation (LLM09)
Show sources for factual answers, add human review where answers carry
consequences (medical, legal, financial), and design the interface so users
understand that answers can be wrong.

## 10. Unbounded consumption (LLM10)
Rate-limit per user, cap input and output tokens, set spending alerts with your
model provider, and time out long-running agent loops. Otherwise an attacker can
run up your bill or take the service down.

---

## If you're building an MCP server or agent tools
- **Authenticate** remote MCP servers (OAuth), and check authorization on every
  tool call. Don't rely only on whether a session exists.
- **Validate tool arguments** as strictly as you'd validate a public API.
  Prevent path traversal, SSRF and injection in what tools do.
- **Tool descriptions are part of the prompt.** Keep them accurate and minimal,
  and review third-party tool descriptions before trusting a server.
- **Log every tool call** with the user, the arguments and the result, so you can
  investigate incidents.

## Quick self-check
- [ ] Every action with side effects needs a human confirmation or a server-side permission check.
- [ ] Model output is escaped, validated, and never executed.
- [ ] Retrieval and tools enforce the **current user's** permissions in code.
- [ ] No secrets in prompts. Assume the system prompt is public.
- [ ] Per-user rate limits, token caps and spending alerts are configured.
- [ ] Third-party models, MCP servers and plugins are pinned and reviewed.
