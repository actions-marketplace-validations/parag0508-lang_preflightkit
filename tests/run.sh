#!/usr/bin/env bash
# Checks the scanner flags the vulnerable fixture and passes the clean one.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
check() { # check <description> <command...>
  if "${@:2}"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi
}

bash scripts/security-check.sh --strict fixtures/vulnerable >/tmp/pk-vuln.log 2>&1
code=$?
check "vulnerable fixture fails in strict mode" [ "$code" -eq 1 ]
[ "$code" -eq 1 ] || cat /tmp/pk-vuln.log
for needle in "search.php" "pickle.loads" "shell=True" "dangerouslySetInnerHTML" "API_KEY"; do
  check "  found: $needle" grep -q "$needle" /tmp/pk-vuln.log
done
if command -v semgrep >/dev/null 2>&1; then
  check "semgrep scanned the fixture files" grep -qE "Targets scanned: [1-9]" /tmp/pk-vuln.log
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

# Monorepo: every folder with a lockfile is audited; dependencies, tests and
# ignored paths are not. A stand-in npm reports vulnerabilities in apps/web only.
mono=$(mktemp -d)
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
gate_tmp=$(mktemp -d)
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
  cli="$PWD/bin/preflightkit.js"; rules_tmp=$(mktemp -d)
  ( cd "$rules_tmp" && printf '# Notes\n' > AGENTS.md && node "$cli" rules >/dev/null && node "$cli" rules >/dev/null )
  check "rules keep existing AGENTS.md content" grep -q '^# Notes' "$rules_tmp/AGENTS.md"
  check "rules add one managed section" [ "$(grep -c 'preflightkit:start' "$rules_tmp/AGENTS.md")" -eq 1 ]
  check "rules create Copilot and Cursor files" \
    test -f "$rules_tmp/.github/copilot-instructions.md" -a -f "$rules_tmp/.cursor/rules/preflightkit.mdc"
  rm -rf "$rules_tmp"
fi
exit $fail
