#!/usr/bin/env bash
#
# security-check.sh — run free security scanners against a project you own.
#
# Usage:
#   ./security-check.sh [options] [path-to-project]   # path defaults to current directory
#
# Options:
#   --audit-level=LEVEL  lowest dependency severity that blocks: low, moderate,
#                        high (default) or critical
#   --include-dev        also audit development dependencies
#   --strict             treat advisory findings as blocking too
#
# Every result is one of:
#   [fail]   blocking: leaked secrets, vulnerable dependencies at or above the
#            audit level, Trivy findings at or above the audit level
#   [warn]   advisory: Semgrep findings, risky code patterns, and dependency
#            vulnerabilities below the audit level. Worth a look; not blocking.
#   [error]  a scanner is installed but could not run, so nothing was checked
#
# Exit code: 1 if anything is blocking, otherwise 2 if a scanner could not run,
# otherwise 0.
#
# To accept a reviewed finding of the pattern check, put "preflightkit-ignore"
# in a comment on the line or the line above, or list paths to skip in
# .preflightkitignore at the project root (also passed to Semgrep and Trivy).
#
# This script only READS your code and dependencies. It does not attack any
# running system. Use it only on code you own or are authorized to work on.
#
# It auto-detects which scanners you have installed and skips the rest, printing
# install hints. Nothing here is destructive.

set -uo pipefail

TARGET=.; AUDIT_LEVEL=high; INCLUDE_DEV=""; PROD_ONLY=1; STRICT=0
for arg in "$@"; do
  case "$arg" in
    --audit-level=*) AUDIT_LEVEL="${arg#*=}" ;;
    --include-dev)   INCLUDE_DEV=1; PROD_ONLY="" ;;
    --strict)        STRICT=1 ;;
    -h|--help)       awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    -*)              echo "security-check.sh: unknown option $arg (see --help)" >&2; exit 2 ;;
    *)               TARGET="$arg" ;;
  esac
done
# Severities at or above the audit level, in each tool's own words.
case "$AUDIT_LEVEL" in
  low)      SEVERITIES='low|moderate|medium|high|critical'; TRIVY_SEVERITY=LOW,MEDIUM,HIGH,CRITICAL ;;
  moderate) SEVERITIES='moderate|medium|high|critical';     TRIVY_SEVERITY=MEDIUM,HIGH,CRITICAL ;;
  high)     SEVERITIES='high|critical';                     TRIVY_SEVERITY=HIGH,CRITICAL ;;
  critical) SEVERITIES='critical';                          TRIVY_SEVERITY=CRITICAL ;;
  *) echo "security-check.sh: --audit-level must be low, moderate, high or critical" >&2; exit 2 ;;
esac
[ -d "$TARGET" ] || { echo "security-check.sh: \"$TARGET\" is not a folder" >&2; exit 2; }

PASS=0; FAIL=0; WARN=0; ERR=0; SKIP=0
FAIL_MSGS=(); WARN_MSGS=(); ERR_MSGS=()

# Workflow commands turn results into annotations on the GitHub run page.
annotate() { # annotate <warning|error> <message> [file line]
  [ "${GITHUB_ACTIONS:-}" = "true" ] || return 0
  local msg="${2//'%'/%25}"; msg="${msg//$'\r'/}"; msg="${msg//$'\n'/%0A}"
  if [ $# -ge 4 ]; then echo "::$1 file=$3,line=$4,title=PreflightKit::$msg"; else echo "::$1 title=PreflightKit::$msg"; fi
}

say()   { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()    { printf '  \033[32m[ok]\033[0m    %s\n' "$1"; PASS=$((PASS+1)); }
fail()  { printf '  \033[31m[fail]\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); FAIL_MSGS+=("$1"); annotate error "$1"; }
warn()  { printf '  \033[33m[warn]\033[0m  %s\n' "$1"; WARN=$((WARN+1)); WARN_MSGS+=("$1"); annotate warning "$1"; }
error() { printf '  \033[35m[error]\033[0m %s\n' "$1"; ERR=$((ERR+1)); ERR_MSGS+=("$1"); annotate error "$1"; }
skip()  { printf '  \033[90m[skip]\033[0m  %s\n' "$1"; SKIP=$((SKIP+1)); }
have()  { command -v "$1" >/dev/null 2>&1; }

# .preflightkitignore: one path or glob per line, relative to the project root.
# "*" also matches across folders; lines starting with "#" are comments.
IGNORES=()
if [ -f "$TARGET/.preflightkitignore" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    line="${line#./}"; line="${line#/}"; line="${line%/}"
    [ -n "$line" ] && [ "${line:0:1}" != "#" ] && IGNORES+=("$line")
  done < "$TARGET/.preflightkitignore"
fi
is_ignored() { # is_ignored <path relative to the project root>
  local p
  for p in ${IGNORES[@]+"${IGNORES[@]}"}; do
    # shellcheck disable=SC2053  # $p is a glob on purpose
    [[ $1 == $p || $1 == $p/* || $1 == */$p || $1 == */$p/* ]] && return 0
  done
  return 1
}

# Build output, dependencies and tests are skipped: tests are full of fake
# secrets and deliberate bad input.
SKIP_DIRS='node_modules vendor dist build .git .next .nuxt coverage __tests__ __mocks__ test tests spec e2e'
SKIP_FILES='*.min.js *.test.* *.spec.* test_*.py *_test.py *_test.go'

printf '\033[1mPreflightKit — security self-check\033[0m\n'
printf 'Target: %s\n' "$(cd "$TARGET" && pwd)"
printf 'Dependency audit level: %s%s\n' "$AUDIT_LEVEL" "${PROD_ONLY:+ (production dependencies only)}"
[ ${#IGNORES[@]} -gt 0 ] && printf 'Skipping paths from .preflightkitignore: %s\n' "${IGNORES[*]}"

# ---------------------------------------------------------------------------
say "1. Secret scanning (code + git history)"
if have gitleaks; then
  # gitleaks 8.19+ uses `git` (repo + history) / `dir` (files only); older versions use `detect`.
  # Leaks exit with 3, so any other non-zero code means gitleaks itself failed.
  if gitleaks git --help >/dev/null 2>&1; then
    if [ -e "$TARGET/.git" ]; then gl=(gitleaks git "$TARGET"); else gl=(gitleaks dir "$TARGET"); fi
  else
    gl=(gitleaks detect --source "$TARGET")
  fi
  gl+=(--no-banner --redact --verbose --exit-code 3)
  [ -f "$TARGET/.gitleaksignore" ] && gl+=(--gitleaks-ignore-path "$TARGET")
  "${gl[@]}"; code=$?
  case $code in
    0) ok "gitleaks found no secrets" ;;
    3) fail "gitleaks found potential secrets — review above (accept a false positive with a gitleaks:allow comment or .gitleaksignore)" ;;
    *) error "gitleaks could not run (exit code $code) — see above" ;;
  esac
elif have trufflehog; then
  trufflehog filesystem --fail "$TARGET"; code=$?
  case $code in
    0)   ok "trufflehog found no secrets" ;;
    183) fail "trufflehog found potential secrets — review above" ;;
    *)   error "trufflehog could not run (exit code $code) — see above" ;;
  esac
else
  skip "no secret scanner. Install: https://github.com/gitleaks/gitleaks"
fi

# ---------------------------------------------------------------------------
say "2. Static analysis (code-level flaws)"
if have semgrep; then
  excludes=(); for p in ${IGNORES[@]+"${IGNORES[@]}"}; do excludes+=(--exclude "$p"); done
  semgrep scan --config=auto --error --no-git-ignore ${excludes[@]+"${excludes[@]}"} "$TARGET"; code=$?
  case $code in
    0) ok "semgrep found no issues" ;;
    1) warn "semgrep flagged issues — review above (accept a reviewed one with a nosemgrep comment)" ;;
    *) error "semgrep could not run (exit code $code) — see above" ;;
  esac
else
  skip "no semgrep. Install: pip install semgrep  (then: semgrep --config=auto)"
fi

# ---------------------------------------------------------------------------
say "3. Dependency audit (known-vulnerable packages)"
ran_dep=0

# run_audit <command...>: run it in $AUDIT_DIR and print its output.
# Leaves the output in $out and the exit code in $code.
run_audit() { ran_dep=1; out=$(cd "$AUDIT_DIR" && "$@" 2>&1); code=$?; printf '%s\n' "$out"; }

# result <name> <error-regex> <clean-regex>: classify the last run of an
# auditor that filters by the audit level itself and exits non-zero on a match.
result() {
  if grep -qE "$2" <<<"$out"; then error "$1 could not run — see the error above. Nothing was audited."
  elif [ "$code" -ne 0 ]; then fail "$1 found $AUDIT_LEVEL or more severe vulnerabilities"
  elif grep -qE "$3" <<<"$out"; then ok "$1 clean"
  else warn "$1 found vulnerabilities below $AUDIT_LEVEL — review above"
  fi
}

# severity_result <name> <severity-regex-prefix>: classify findings by the
# severity printed next to each one, for auditors without a severity filter.
severity_result() {
  if grep -qiE "$2($SEVERITIES)\b" <<<"$out"; then fail "$1 found $AUDIT_LEVEL or more severe vulnerabilities"
  else warn "$1 found vulnerabilities below $AUDIT_LEVEL — review above"
  fi
}

# audit_dir <folder relative to the project>: run every auditor that applies there.
audit_dir() {
  local at=""; [ "$1" = "." ] || at=" ($1)"
  AUDIT_DIR="$TARGET/$1"
  if [ -f "$AUDIT_DIR/composer.lock" ] && have composer; then
    run_audit composer audit --locked ${PROD_ONLY:+--no-dev}
    case $code in   # bit 1: vulnerable packages, bit 2: abandoned packages
      0)   ok "composer audit$at clean" ;;
      1|3) severity_result "composer audit$at" 'Severity[ |]+' ;;
      2)   warn "composer audit$at found abandoned packages — review above" ;;
      *)   error "composer audit$at could not run — see the error above. Nothing was audited." ;;
    esac
  fi
  if [ -f "$AUDIT_DIR/package-lock.json" ] && have npm; then
    run_audit npm audit --audit-level="$AUDIT_LEVEL" ${PROD_ONLY:+--omit=dev}
    result "npm audit$at" '^npm (ERR!|error) ' 'found 0 vulnerabilities'
  fi
  if [ -f "$AUDIT_DIR/pnpm-lock.yaml" ] && have pnpm; then
    run_audit pnpm audit --audit-level "$AUDIT_LEVEL" ${PROD_ONLY:+--prod}
    result "pnpm audit$at" 'ERR_PNPM_' 'No known vulnerabilities found'
  fi
  if [ -f "$AUDIT_DIR/yarn.lock" ] && have yarn; then
    if [[ "$( cd "$AUDIT_DIR" && yarn --version 2>/dev/null )" == 1.* ]]; then
      run_audit yarn audit --level "$AUDIT_LEVEL" ${PROD_ONLY:+--groups dependencies}
      result "yarn audit$at" '^error ' '^0 vulnerabilities found'
    else
      run_audit yarn npm audit --recursive --severity "$AUDIT_LEVEL" ${PROD_ONLY:+--environment production}
      result "yarn npm audit$at" 'Usage Error|Internal Error|YN0001' 'No audit suggestions'
    fi
  fi
  if { [ -f "$AUDIT_DIR/requirements.txt" ] || [ -f "$AUDIT_DIR/pyproject.toml" ]; } && have pip-audit; then
    if [ -f "$AUDIT_DIR/requirements.txt" ]; then run_audit pip-audit -r requirements.txt; else run_audit pip-audit .; fi
    if [ "$code" -eq 0 ]; then ok "pip-audit$at clean"
    elif grep -qE 'Found [0-9]+ known vulnerabilit' <<<"$out"; then fail "pip-audit$at found known vulnerabilities (it reports no severity, so all of them block)"
    else error "pip-audit$at could not run — see the error above. Nothing was audited."
    fi
  fi
  if [ -f "$AUDIT_DIR/go.mod" ] && have govulncheck; then
    run_audit govulncheck ./...
    case $code in
      0) ok "govulncheck$at clean" ;;
      3) fail "govulncheck$at found vulnerabilities your code actually calls" ;;
      *) error "govulncheck$at could not run — see the error above. Nothing was audited." ;;
    esac
  fi
  if [ -f "$AUDIT_DIR/Gemfile.lock" ] && have bundle-audit; then
    run_audit bundle-audit check --update
    if [ "$code" -eq 0 ]; then ok "bundle-audit$at clean"
    elif grep -q 'Vulnerabilities found' <<<"$out"; then severity_result "bundle-audit$at" 'Criticality: '
    else error "bundle-audit$at could not run — see the error above. Nothing was audited."
    fi
  fi
  if ls "$AUDIT_DIR"/*.csproj "$AUDIT_DIR"/*.sln >/dev/null 2>&1 && have dotnet; then
    run_audit dotnet list package --vulnerable --include-transitive
    if [ "$code" -ne 0 ]; then error "dotnet package check$at could not run — see the error above. Nothing was audited."
    elif grep -q "has the following vulnerable packages" <<<"$out"; then severity_result "dotnet package check$at" '^ *>.* '
    else ok "dotnet package check$at clean"
    fi
  fi
}

# Every folder with a lockfile or manifest, up to 3 levels down, so monorepos
# (apps/web, packages/api, services/*) are covered. A workspace with one root
# lockfile is audited once, at the root.
MANIFESTS='package-lock.json pnpm-lock.yaml yarn.lock composer.lock requirements.txt pyproject.toml go.mod Gemfile.lock *.csproj *.sln'
set -f
names=(); for m in $MANIFESTS; do names+=(-o -name "$m"); done
prune=(); for d in $SKIP_DIRS fixtures .venv venv; do prune+=(-o -name "$d"); done
set +f
dep_dirs=()
while IFS= read -r d; do
  d="${d#./}"; [ -n "$d" ] || d="."
  [ "$d" != "." ] && is_ignored "$d" && continue
  dep_dirs+=("$d")
done < <(cd "$TARGET" && find . -maxdepth 4 \( "${prune[@]:1}" \) -prune -o -type f \( "${names[@]:1}" \) -print 2>/dev/null \
           | sed 's|/[^/]*$||' | sort -u)
if [ ${#dep_dirs[@]} -gt 25 ]; then
  echo "  ${#dep_dirs[@]} folders with dependencies found; auditing the first 25. Skip the rest in .preflightkitignore."
  dep_dirs=("${dep_dirs[@]:0:25}")
fi
[ ${#dep_dirs[@]} -gt 1 ] && echo "  Auditing ${#dep_dirs[@]} folders: ${dep_dirs[*]}"
for d in ${dep_dirs[@]+"${dep_dirs[@]}"}; do audit_dir "$d"; done
if { [ -f "$TARGET/pom.xml" ] || [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ]; }; then
  echo "  Java project detected: dependency CVEs are covered by the Trivy step below,"
  echo "  or run: mvn org.owasp:dependency-check-maven:check"
fi
[ "$ran_dep" -eq 0 ] && skip "no dependency manifest found, or its audit tool isn't installed (Trivy below still scans dependencies)"

# ---------------------------------------------------------------------------
say "4. Filesystem / container vulnerability scan"
if have trivy; then
  # Local .env files are expected to hold secrets and should be gitignored;
  # committed secrets are caught by gitleaks above. Skipping them avoids false
  # alarms and keeps real credentials out of the output.
  # Findings exit with 3, so any other non-zero code means Trivy itself failed.
  tv=(trivy fs --quiet --scanners "vuln,secret,misconfig" --severity "$TRIVY_SEVERITY" --exit-code 3
      --skip-dirs "**/node_modules" --skip-dirs "**/.git" --skip-dirs "**/.next"
      --skip-files "**/.env" --skip-files "**/.env.local" --skip-files "**/.env.*.local")
  for p in ${IGNORES[@]+"${IGNORES[@]}"}; do tv+=(--skip-dirs "**/$p" --skip-files "**/$p"); done
  [ -n "$INCLUDE_DEV" ] && tv+=(--include-dev-deps)
  [ -f "$TARGET/.trivyignore" ] && tv+=(--ignorefile "$TARGET/.trivyignore")
  "${tv[@]}" "$TARGET"; code=$?
  case $code in
    0) ok "trivy found no $TRIVY_SEVERITY issues" ;;
    3) fail "trivy found $TRIVY_SEVERITY vulnerabilities, secrets or misconfigurations — review above (accept one in .trivyignore)" ;;
    *) error "trivy could not run (exit code $code) — see above" ;;
  esac
else
  skip "no trivy. Install: https://aquasecurity.github.io/trivy"
fi

# ---------------------------------------------------------------------------
say "5. Quick heuristic grep (dangerous patterns)"
# Covering PHP, JS/TS, Python, Ruby, Java, Go, C#. Matches are advisory.
CODE_PATTERNS='eval\(|unserialize\(|shell_exec\(|system\(|md5\(|SELECT .*(\$|\+ *[a-zA-Z_]|#\{|%s'"'"' %)|pickle\.loads|yaml\.load\(|shell=True|new Function\(|dangerouslySetInnerHTML|v-html|html_safe|\.constantize|Marshal\.load|ObjectInputStream|BinaryFormatter|FromSqlRaw\(|text/template'
SECRET_PATTERN='(password|secret|api_?key|token) *[:=] *["'"'"'][^"'"'"']{8,}'
PLACEHOLDER='test|fake|dummy|example|sample|placeholder|changeme|xxxx|your[_-]'
# Only source files are searched, so docs and examples don't cause false alarms.
EXTS='php|phtml|js|jsx|mjs|cjs|ts|tsx|vue|svelte|py|rb|erb|java|kt|go|cs|cshtml|razor'
if have rg; then
  globs=(-g "*.{${EXTS//|/,}}"); for d in $SKIP_DIRS; do globs+=(-g "!$d"); done
  set -f; for f in $SKIP_FILES; do globs+=(-g "!$f"); done; set +f
  raw=$(cd "$TARGET" && rg -n --no-heading -i "${globs[@]}" -e "$CODE_PATTERNS|$SECRET_PATTERN" . 2>/dev/null | head -n 500)
else
  opts=(); for e in ${EXTS//|/ }; do opts+=(--include="*.$e"); done
  for d in $SKIP_DIRS; do opts+=(--exclude-dir="$d"); done
  set -f; for f in $SKIP_FILES; do opts+=(--exclude="$f"); done; set +f
  raw=$(cd "$TARGET" && grep -rniE "${opts[@]}" "$CODE_PATTERNS|$SECRET_PATTERN" . 2>/dev/null | head -n 500)
fi
# Drop accepted and known-safe matches. Paths are "./file:line:text".
kept=0; ignored=0; shown=""
while IFS= read -r m; do
  [ -n "$m" ] || continue
  file="${m%%:*}"; file="${file#./}"; rest="${m#*:}"; n="${rest%%:*}"; text="${rest#*:}"
  if is_ignored "$file" || [[ "$text" == *preflightkit-ignore* ]] \
     || { [ "$n" -gt 1 ] && sed -n "$((n-1))p" "$TARGET/$file" | grep -q 'preflightkit-ignore'; }; then
    ignored=$((ignored+1)); continue
  fi
  # Only one pattern matched and it's a known-safe use: skip it.
  if ! grep -qiE "$CODE_PATTERNS" <<<"$text" && grep -qiE "$PLACEHOLDER" <<<"$text"; then
    continue   # hard-coded "secret" that is an obvious placeholder
  fi
  lower=$(tr '[:upper:]' '[:lower:]' <<<"$text")
  if [[ "$lower" == *dangerouslysetinnerhtml* ]] && ! grep -qiE "$CODE_PATTERNS|$SECRET_PATTERN" <<<"${lower//dangerouslysetinnerhtml/}" \
     && sed -n "${n},$((n+2))p" "$TARGET/$file" | grep -q 'JSON\.stringify('; then
    continue   # serialized data, e.g. a JSON-LD <script> tag
  fi
  kept=$((kept+1))
  if [ "$kept" -le 40 ]; then
    shown+="$file:$n:$text"$'\n'
    # Annotation paths are relative to the repository root.
    apath="${TARGET%/}/$file"; apath="${apath#"${GITHUB_WORKSPACE:-}/"}"; apath="${apath#./}"
    [ "$kept" -le 10 ] && annotate warning "Risky pattern: ${text#"${text%%[![:space:]]*}"}" "$apath" "$n"
  fi
done <<<"$raw"
[ "$ignored" -gt 0 ] && echo "  ($ignored match(es) accepted via preflightkit-ignore or .preflightkitignore)"
if [ "$kept" -gt 0 ]; then
  printf '%s' "$shown"
  [ "$kept" -gt 40 ] && echo "  ... and $((kept-40)) more"
  warn "$kept risky pattern(s) above — review them; accept a safe one with a preflightkit-ignore comment"
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
BLOCKING=$FAIL; [ "$STRICT" -eq 1 ] && BLOCKING=$((FAIL+WARN))
printf '\n\033[1m==> Summary\033[0m\n'
printf '  ok: %d   blocking: %d   advisory: %d   scanner errors: %d   skipped: %d\n' "$PASS" "$FAIL" "$WARN" "$ERR" "$SKIP"
[ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ] && printf '  --strict: advisory findings count as blocking\n'
[ "$ERR" -gt 0 ] && printf '  A scanner could not run, so part of the check is missing. Fix the error above and re-run.\n'
printf '\nNext: fix blocking findings first, then review advisory ones by real risk.\n'
printf 'For dynamic scanning of a RUNNING app, use OWASP ZAP separately.\n'

# In GitHub Actions, also write a summary to the run page and expose the counts.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    if [ "$BLOCKING" -gt 0 ]; then echo "## ❌ PreflightKit: $BLOCKING blocking finding(s)"
    elif [ "$ERR" -gt 0 ]; then echo "## ⚠️ PreflightKit: $ERR scanner(s) could not run"
    elif [ "$WARN" -gt 0 ]; then echo "## ✅ PreflightKit: nothing blocking, $WARN advisory finding(s)"
    else echo "## ✅ PreflightKit: all clear"; fi
    echo
    echo "| ok | blocking | advisory | scanner errors | skipped |"
    echo "|---|---|---|---|---|"
    echo "| $PASS | $FAIL | $WARN | $ERR | $SKIP |"
    [ "$FAIL" -gt 0 ] && { echo; echo "**Blocking:**"; for m in "${FAIL_MSGS[@]}"; do echo "- $m"; done; }
    [ "$ERR" -gt 0 ]  && { echo; echo "**Could not run:**"; for m in "${ERR_MSGS[@]}"; do echo "- $m"; done; }
    if [ "$WARN" -gt 0 ]; then
      echo; if [ "$STRICT" -eq 1 ]; then echo "**Advisory (blocking in strict mode):**"; else echo "**Advisory:**"; fi
      for m in "${WARN_MSGS[@]}"; do echo "- $m"; done
    fi
    echo; echo "Details are in the job log. [Checklist](https://github.com/parag0508-lang/preflightkit/blob/main/SECURITY-CHECKLIST.md)"
  } >> "$GITHUB_STEP_SUMMARY"
fi
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  { echo "blocking=$BLOCKING"; echo "warnings=$WARN"; echo "errors=$ERR"; } >> "$GITHUB_OUTPUT"
fi

if [ "$BLOCKING" -gt 0 ]; then exit 1; elif [ "$ERR" -gt 0 ]; then exit 2; else exit 0; fi
