# Contributing

Thank you for helping make apps safer. This project is meant to be useful to
developers everywhere, so clear and accurate contributions matter more than long
ones.

## Good first contributions
- **Add a framework guide.** Copy any file in `docs/security/` and keep its
  structure: *top risks → the fix in code → a quick self-check*.
- **Fix something wrong or outdated.** Versions and CVEs change. Link the
  official source in your pull request.
- **Translate.** Add `docs/<language-code>/` (for example `docs/hi/`) and translate
  the checklist first.
- **Improve the script.** Add detection for another ecosystem's native auditor.
- **Pick a 📋 item** from the [ROADMAP](./ROADMAP.md).

## Ground rules
1. **Defensive only.** No exploit code, payloads, attack tooling, or instructions
   for testing systems you don't own. Pull requests that include them will be closed.
2. **Cite sources** for version numbers, CVEs and claims. Prefer official advisories,
   NVD, CISA, OWASP, and framework documentation.
3. **Plain language.** Write for a developer who isn't a security specialist.
   Show the fix in code.
4. **Keep it short.** If a section grows past a screen, consider splitting it.

## How to submit
1. Fork the repo and create a branch: `git checkout -b add-laravel-guide`.
2. Make your change. If you edited the script, run `bash -n scripts/security-check.sh`.
3. Open a pull request that explains what you changed and why, with sources.

By contributing you agree that your work is licensed under the project's
[MIT License](./LICENSE), and you agree to follow the [Code of Conduct](./CODE_OF_CONDUCT.md).
