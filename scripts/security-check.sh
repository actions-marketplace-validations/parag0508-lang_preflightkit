#!/usr/bin/env bash
#
# security-check.sh — run free security scanners against a project you own.
#
# Usage:
#   ./security-check.sh [path-to-project]   # defaults to current directory
#
# This script only READS your code and dependencies. It does not attack any
# running system. Use it only on code you own or are authorized to work on.
#
# It auto-detects which scanners you have installed and skips the rest, printing
# install hints. Nothing here is destructive.

set -uo pipefail

TARGET="${1:-.}"
PASS=0; WARN=0; SKIP=0

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m[ok]\033[0m   %s\n'  "$1"; PASS=$((PASS+1)); }
WARN_MSGS=()
warn() { printf '  \033[33m[warn]\033[0m %s\n'  "$1"; WARN=$((WARN+1)); WARN_MSGS+=("$1"); }
skip() { printf '  \033[90m[skip]\033[0m %s\n'  "$1"; SKIP=$((SKIP+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

printf '\033[1mPreflightKit — security self-check\033[0m\n'
printf 'Target: %s\n' "$(cd "$TARGET" && pwd)"

# ---------------------------------------------------------------------------
say "1. Secret scanning (code + git history)"
if have gitleaks; then
  # gitleaks 8.19+ uses `git` (repo + history) / `dir` (files only); older versions use `detect`.
  if gitleaks git --help >/dev/null 2>&1; then
    if [ -e "$TARGET/.git" ]; then gl=(gitleaks git --no-banner "$TARGET"); else gl=(gitleaks dir --no-banner "$TARGET"); fi
  else
    gl=(gitleaks detect --no-banner --source "$TARGET")
  fi
  if "${gl[@]}"; then
    ok "gitleaks found no secrets"
  else
    warn "gitleaks flagged potential secrets — review above"
  fi
elif have trufflehog; then
  if trufflehog filesystem --fail "$TARGET"; then ok "trufflehog found no secrets"; else warn "trufflehog flagged potential secrets — review above"; fi
else
  skip "no secret scanner. Install: https://github.com/gitleaks/gitleaks"
fi

# ---------------------------------------------------------------------------
say "2. Static analysis (code-level flaws)"
if have semgrep; then
  if semgrep scan --config=auto --error --no-git-ignore "$TARGET"; then
    ok "semgrep found no blocking issues"
  else
    warn "semgrep flagged issues — review above"
  fi
else
  skip "no semgrep. Install: pip install semgrep  (then: semgrep --config=auto)"
fi

# ---------------------------------------------------------------------------
say "3. Dependency audit (known-vulnerable packages)"
ran_dep=0
if [ -f "$TARGET/composer.lock" ] && have composer; then
  ran_dep=1; ( cd "$TARGET" && composer audit ) && ok "composer audit clean" || warn "composer audit flagged packages"
fi
if [ -f "$TARGET/package-lock.json" ] && have npm; then
  ran_dep=1; ( cd "$TARGET" && npm audit ) && ok "npm audit clean" || warn "npm audit flagged packages"
fi
if [ -f "$TARGET/pnpm-lock.yaml" ] && have pnpm; then
  ran_dep=1; ( cd "$TARGET" && pnpm audit ) && ok "pnpm audit clean" || warn "pnpm audit flagged packages"
fi
if [ -f "$TARGET/yarn.lock" ] && have yarn; then
  ran_dep=1; ( cd "$TARGET" && yarn npm audit 2>/dev/null || yarn audit ) && ok "yarn audit clean" || warn "yarn audit flagged packages"
fi
if { [ -f "$TARGET/requirements.txt" ] || [ -f "$TARGET/pyproject.toml" ]; } && have pip-audit; then
  ran_dep=1; ( cd "$TARGET" && pip-audit ) && ok "pip-audit clean" || warn "pip-audit flagged packages"
fi
if [ -f "$TARGET/go.mod" ] && have govulncheck; then
  ran_dep=1; ( cd "$TARGET" && govulncheck ./... ) && ok "govulncheck clean" || warn "govulncheck flagged reachable vulnerabilities"
fi
if [ -f "$TARGET/Gemfile.lock" ] && have bundle-audit; then
  ran_dep=1; ( cd "$TARGET" && bundle-audit check --update ) && ok "bundle-audit clean" || warn "bundle-audit flagged gems"
fi
if ls "$TARGET"/*.csproj "$TARGET"/*.sln >/dev/null 2>&1 && have dotnet; then
  ran_dep=1
  out=$( cd "$TARGET" && dotnet list package --vulnerable --include-transitive 2>&1 )
  echo "$out"
  if echo "$out" | grep -q "has the following vulnerable packages"; then
    warn "dotnet flagged vulnerable packages"
  else
    ok "dotnet package check clean"
  fi
fi
if { [ -f "$TARGET/pom.xml" ] || [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ]; }; then
  echo "  Java project detected: dependency CVEs are covered by the Trivy step below,"
  echo "  or run: mvn org.owasp:dependency-check-maven:check"
fi
[ "$ran_dep" -eq 0 ] && skip "no dependency manifest found, or its audit tool isn't installed (Trivy below still scans dependencies)"

# ---------------------------------------------------------------------------
say "4. Filesystem / container vulnerability scan"
if have trivy; then
  if trivy fs --quiet --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --exit-code 1 "$TARGET"; then
    ok "trivy found no HIGH/CRITICAL issues"
  else
    warn "trivy flagged HIGH/CRITICAL vulnerabilities, secrets or misconfigurations — review above"
  fi
else
  skip "no trivy. Install: https://aquasecurity.github.io/trivy"
fi

# ---------------------------------------------------------------------------
say "5. Quick heuristic grep (dangerous patterns)"
# One pattern per line, covering PHP, JS/TS, Python, Ruby, Java, Go, C#.
PATTERNS='eval\(|unserialize\(|shell_exec\(|system\(|md5\(|SELECT .*(\$|\+ *[a-zA-Z_]|#\{|%s'"'"' %)|pickle\.loads|yaml\.load\(|shell=True|new Function\(|dangerouslySetInnerHTML|v-html|html_safe|\.constantize|Marshal\.load|ObjectInputStream|BinaryFormatter|FromSqlRaw\(|text/template|(password|secret|api_?key|token) *[:=] *["'"'"'][^"'"'"']{8,}'
# Only source files are searched, so docs and examples don't cause false alarms.
EXTS='php|phtml|js|jsx|mjs|cjs|ts|tsx|vue|svelte|py|rb|erb|java|kt|go|cs|cshtml|razor'
if have rg; then
  matches=$(rg -n --no-heading -i -g '!node_modules' -g '!vendor' -g '!dist' -g '!build' -g '!*.min.js' \
    -g "*.{${EXTS//|/,}}" -e "$PATTERNS" "$TARGET" 2>/dev/null | head -n 40)
else
  matches=$(grep -rniE "$PATTERNS" "$TARGET" 2>/dev/null | grep -E "\.(${EXTS}):[0-9]+:" \
    | grep -vE '/(node_modules|vendor|dist|build|\.git)/|\.min\.js:' | head -n 40)
fi
if [ -n "$matches" ]; then
  echo "$matches"
  warn "review the matches above; some may be false positives"
else
  ok "no obvious dangerous patterns"
fi

# ---------------------------------------------------------------------------
say "6. Exposed secrets at the web root (manual reminder)"
echo "  Confirm these are NOT web-accessible on your running app:"
echo "    /.env  /.git/config  /config.php  /composer.lock  /backup.sql"
echo "  Each should return 404, never file contents."
skip "manual check — run against your live URL with curl once deployed"

# ---------------------------------------------------------------------------
printf '\n\033[1m==> Summary\033[0m\n'
printf '  ok: %d   warn: %d   skipped: %d\n' "$PASS" "$WARN" "$SKIP"
printf '\nNext: fix warnings by real risk (internet-facing + critical first).\n'
printf 'For dynamic scanning of a RUNNING app, use OWASP ZAP separately.\n'

# In GitHub Actions, also write a summary to the run page.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    if [ "$WARN" -gt 0 ]; then echo "## ⚠️ PreflightKit: $WARN warning(s)"; else echo "## ✅ PreflightKit: no warnings"; fi
    echo
    echo "| ok | warnings | skipped |"
    echo "|---|---|---|"
    echo "| $PASS | $WARN | $SKIP |"
    if [ "$WARN" -gt 0 ]; then
      echo; echo "**Review in the job log:**"
      for m in "${WARN_MSGS[@]}"; do echo "- $m"; done
    fi
    echo; echo "Fix by real risk: internet-facing and actively exploited first. [Checklist](https://github.com/parag0508-lang/preflightkit/blob/main/SECURITY-CHECKLIST.md)"
  } >> "$GITHUB_STEP_SUMMARY"
fi

# Exit non-zero if anything warned, so CI can gate on it.
[ "$WARN" -gt 0 ] && exit 1 || exit 0
