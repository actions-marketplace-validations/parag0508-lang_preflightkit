---
name: dependency-vetting
description: Check that a package is real, maintained and safe before it's added to a project, and audit dependencies after changes. Use whenever about to install or suggest a new npm, pip, composer, gem, Go, Maven or NuGet package, when the user asks whether a library is safe or trustworthy, or after a lockfile changes.
---

# Dependency vetting

AI assistants sometimes suggest packages that don't exist. Attackers register
those names, a practice called "slopsquatting", along with typos of popular
packages. Check every new dependency before installing it.

## Before adding a package

1. **Ask whether it's needed.** If the standard library or an existing dependency
   already does this, prefer that. Every package is code you're trusting.

2. **Confirm it exists on the official registry, and look at the facts:**
   | Ecosystem | Command |
   |---|---|
   | npm | `npm view <pkg> name version time.modified repository.url maintainers` |
   | PyPI | `pip index versions <pkg>` and the page at pypi.org/project/&lt;pkg&gt; |
   | Composer | `composer show -a <vendor/pkg>` |
   | RubyGems | `gem info <gem> --remote` |
   | Go | `go list -m -versions <module>` |
   | NuGet | `dotnet package search <pkg> --exact-match` |

3. **Red flags.** If any of these apply, stop and tell the user:
   - The package doesn't exist, or was first published very recently.
   - The name is one character off from a popular package (`reqeusts`,
     `lodahs`), or a popular name with an extra word added (`-utils`, `-js`).
   - No source repository is linked, or the repo doesn't match the package.
   - The download count is tiny compared to the role it claims to fill.
   - It has install scripts (`preinstall`/`postinstall`) that don't make sense
     for what it does.
   - It hasn't been updated in years and has open security issues.

4. **Pin it.** Commit the lockfile, and install with the reproducible command
   (`npm ci`, `pip install -r` with hashes where possible, `composer install`,
   `bundle install --frozen`).

## After dependencies change
Run the native auditor and fix or explain anything rated high or critical:
`npm audit --audit-level=high` · `pip-audit` · `composer audit` ·
`bundle-audit check --update` · `govulncheck ./...` ·
`dotnet list package --vulnerable --include-transitive` · or `trivy fs .` for any stack.

## Output
Give a short verdict for each package, in this form:
**`<pkg>@<version>`: OK / Caution / Don't install.** Follow it with one line of
evidence (age, maintainers, repo, downloads) and, if not OK, a safer alternative.
