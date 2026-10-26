#!/usr/bin/env bash
# Checks the scanner flags the vulnerable fixture and passes the clean one.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
check() { # check <description> <command...>
  if "${@:2}"; then echo "PASS $1"; else echo "FAIL $1"; fail=1
    [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::error title=Test failed::$1"; fi
}
# Temp projects live under RUNNER_TEMP in CI: the containerized scanners can't
# see the rest of the runner's /tmp.
tmpdir() { mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pk-test.XXXXXX"; }

bash scripts/security-check.sh --strict fixtures/vulnerable >/tmp/pk-vuln.log 2>&1
code=$?
check "vulnerable fixture fails in strict mode" [ "$code" -eq 1 ]
[ "$code" -eq 1 ] || cat /tmp/pk-vuln.log
for needle in "search.php" "pickle.loads" "shell=True" "dangerouslySetInnerHTML" "API_KEY"; do
  check "  found: $needle" grep -q "$needle" /tmp/pk-vuln.log
done
if command -v semgrep >/dev/null 2>&1; then
  check "semgrep reported its own findings" grep -qE "python\.lang\.security|typescript\.react\.security|php\.lang\.security" /tmp/pk-vuln.log
fi

bash scripts/security-check.sh fixtures/clean >/tmp/pk-clean.log 2>&1
code=$?
check "clean fixture passes" [ "$code" -eq 0 ]
[ "$code" -eq 0 ] || cat /tmp/pk-clean.log
check "  pattern check is clean" grep -q "no obvious dangerous patterns" /tmp/pk-clean.log
check "  inline and file ignores were applied" grep -q "2 match(es) accepted" /tmp/pk-clean.log
for skipped in "webhook.test.js" "JsonLd.jsx" "legacy/old.php" "cache.py"; do
  check "  not reported: $skipped" bash -c "! grep -q '$skipped:' /tmp/pk-clean.log"
done

bash scripts/security-check.sh --audit-level=bogus fixtures/clean >/dev/null 2>&1
check "bad option exits with 2" [ $? -eq 2 ]

# SARIF: every report written is valid JSON with the PreflightKit run in it.
sarif_tmp=$(tmpdir)
bash scripts/security-check.sh --sarif-dir="$sarif_tmp" fixtures/vulnerable >/dev/null 2>&1
check "SARIF report written" test -s "$sarif_tmp/preflightkit.sarif"
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  py=$(command -v python3 || command -v python)
  for f in "$sarif_tmp"/*.sarif; do
    check "  valid SARIF: $(basename "$f")" "$py" -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); assert d["runs"][0]["tool"]["driver"]["name"]' "$f"
  done
  check "  pattern findings in SARIF" "$py" -c 'import json,sys; assert len(json.load(open(sys.argv[1],encoding="utf-8"))["runs"][0]["results"]) == 5' "$sarif_tmp/preflightkit.sarif"
fi
rm -rf "$sarif_tmp"

# Baseline: accept today's findings, then only new ones are reported.
bl=$(tmpdir); cp fixtures/vulnerable/* "$bl/"
# A git repo, as in real projects: Semgrep's baseline is a commit.
( cd "$bl" && git init -q && git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init )
bash scripts/security-check.sh --write-baseline "$bl" >/dev/null 2>&1
check "baseline written" grep -q '^pattern loader.py:return pickle.loads(data)$' "$bl/.preflightkit-baseline"
bash scripts/security-check.sh --strict "$bl" >/tmp/pk-bl.log 2>&1
check "  strict run passes once findings are baselined" [ $? -eq 0 ]
echo 'eval(user_input)' >> "$bl/loader.py"
bash scripts/security-check.sh --strict "$bl" >/tmp/pk-bl.log 2>&1
check "  a new finding is still reported" grep -q 'loader.py:[0-9]*:eval(user_input)' /tmp/pk-bl.log
bash scripts/security-check.sh --strict --no-baseline "$bl" >/dev/null 2>&1
check "  --no-baseline reports everything" [ $? -eq 1 ]
rm -rf "$bl"

# Monorepo: every folder with a lockfile is audited; dependencies, tests and
# ignored paths are not. A stand-in npm reports vulnerabilities in apps/web only.
mono=$(tmpdir)
mkdir -p "$mono/bin" "$mono/p/apps/web" "$mono/p/apps/docs" "$mono/p/node_modules/x" "$mono/p/tests/x" "$mono/p/old"
for d in . apps/web apps/docs node_modules/x tests/x old; do echo '{}' > "$mono/p/$d/package-lock.json"; done
echo 'old' > "$mono/p/.preflightkitignore"
printf '#!/usr/bin/env bash\ncase "$PWD" in *apps/web) echo "1 vulnerability (1 high)"; exit 1 ;; esac\necho "found 0 vulnerabilities"\n' > "$mono/bin/npm"
chmod +x "$mono/bin/npm"
PATH="$mono/bin:$PATH" bash scripts/security-check.sh "$mono/p" >/tmp/pk-mono.log 2>&1
code=$?
check "monorepo: blocking finding in a sub-app fails" [ "$code" -eq 1 ]
check "  apps/web is audited and flagged" grep -q 'npm audit (apps/web) found high' /tmp/pk-mono.log
check "  root and apps/docs are audited" grep -q 'Auditing 3 folders: . apps/docs apps/web' /tmp/pk-mono.log
rm -rf "$mono"

# Deploy gate hook: feed it Claude Code's PreToolUse input.
gate() { # gate <project> <command> [scanner options] -> prints the hook's output
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" \
    | CLAUDE_PROJECT_DIR="$1" PREFLIGHTKIT_DEPLOY_ARGS="${3:-}" TMPDIR="$gate_tmp" \
      bash plugins/preflightkit/hooks/deploy-gate.sh
}
gate_tmp=$(tmpdir)
for c in "ls -la" "npm run build" "git push origin feature/login"; do
  check "gate ignores: $c" [ -z "$(gate fixtures/vulnerable "$c" --strict)" ]
done
for c in "vercel --prod" "npx netlify deploy --prod" "fly deploy" "git push origin main" "npm run deploy"; do
  check "gate denies: $c" bash -c "grep -q '\"permissionDecision\":\"deny\"' <<<'$(gate fixtures/vulnerable "$c" --strict)'"
done
check "gate allows a clean project" [ -z "$(gate fixtures/clean "vercel --prod")" ]
check "gate remembers a clean result" bash -c "ls '$gate_tmp' | grep -q '\.ok$'"
rm -rf "$gate_tmp"

# AI assistant rules: written once, then left alone on a re-run.
if command -v node >/dev/null 2>&1; then
  cli="$PWD/bin/preflightkit.js"; rules_tmp=$(tmpdir)
  ( cd "$rules_tmp" && printf '# Notes\n' > AGENTS.md && node "$cli" rules >/dev/null && node "$cli" rules >/dev/null )
  check "rules keep existing AGENTS.md content" grep -q '^# Notes' "$rules_tmp/AGENTS.md"
  check "rules add one managed section" [ "$(grep -c 'preflightkit:start' "$rules_tmp/AGENTS.md")" -eq 1 ]
  check "rules create Copilot and Cursor files" \
    test -f "$rules_tmp/.github/copilot-instructions.md" -a -f "$rules_tmp/.cursor/rules/preflightkit.mdc"
  rm -rf "$rules_tmp"

  # Pre-commit hook: installed once; with gitleaks, a staged secret is refused.
  repo=$(tmpdir)
  ( cd "$repo" && git init -q && git config user.email t@example.com && git config user.name t \
      && node "$cli" pre-commit >/dev/null && node "$cli" pre-commit >/dev/null )
  check "pre-commit hook installed once" [ "$(grep -c 'preflightkit:start' "$repo/.git/hooks/pre-commit")" -eq 1 ]
  if command -v gitleaks >/dev/null 2>&1; then
    ( cd "$repo" && echo 'API_KEY = "Zq8vR2mN4pL7tY1wK3pQ9"' > leak.py && git add leak.py && git commit -qm leak ) >/dev/null 2>&1
    check "pre-commit hook refuses a staged secret" [ -z "$(git -C "$repo" log --oneline 2>/dev/null)" ]
  fi
  rm -rf "$repo"
fi
exit $fail
