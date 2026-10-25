#!/usr/bin/env bash
# Checks the scanner flags the vulnerable fixture and passes the clean one.
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
bash scripts/security-check.sh fixtures/vulnerable >/tmp/pk-vuln.log 2>&1
[ $? -eq 1 ] && echo "PASS vulnerable fixture is flagged" || { echo "FAIL vulnerable fixture not flagged"; cat /tmp/pk-vuln.log; fail=1; }
for needle in "search.php" "pickle.loads" "shell=True" "dangerouslySetInnerHTML" "API_KEY"; do
  grep -q "$needle" /tmp/pk-vuln.log && echo "PASS   found: $needle" || { echo "FAIL   missed: $needle"; fail=1; }
done
if command -v semgrep >/dev/null 2>&1; then
  grep -qE "python\.lang\.security|typescript\.react\.security|php\.lang\.security" /tmp/pk-vuln.log && echo "PASS semgrep reported its own findings" || { echo "FAIL semgrep reported nothing"; fail=1; }
fi
bash scripts/security-check.sh fixtures/clean >/tmp/pk-clean.log 2>&1
[ $? -eq 0 ] && echo "PASS clean fixture passes" || { echo "FAIL clean fixture was flagged"; cat /tmp/pk-clean.log; fail=1; }
exit $fail
