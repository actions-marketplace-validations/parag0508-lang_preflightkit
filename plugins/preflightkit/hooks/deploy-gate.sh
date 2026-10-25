#!/usr/bin/env bash
#
# deploy-gate.sh — PreflightKit deploy gate, a Claude Code PreToolUse hook.
#
# Before Claude runs a deploy command (vercel --prod, git push to main,
# fly deploy, firebase deploy, npm run deploy and similar), this runs the
# PreflightKit scanner on the project:
#   - blocking findings: the command is denied and Claude is told why
#   - a scanner could not run: you're asked before the deploy goes ahead
#   - otherwise the command runs as normal
# A clean result is remembered until the code changes, so repeated deploys
# don't re-scan.
#
# Settings (environment variables, e.g. in settings.json "env"):
#   PREFLIGHTKIT_DEPLOY_GATE  block (default) | ask (ask you instead of denying) | off
#   PREFLIGHTKIT_DEPLOY_ARGS  extra scanner options, e.g. "--audit-level=critical"

set -uo pipefail

MODE="${PREFLIGHTKIT_DEPLOY_GATE:-block}"
[ "$MODE" = "off" ] && exit 0

input=$(cat)

# Read a string field from the hook's JSON input without needing jq.
json_field() {
  printf '%s' "$input" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -n 1 \
    | sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//; s/\\\\\"/\"/g; s/\\\\\\\\/\\\\/g"
}

cmd=$(json_field command)
[ -n "$cmd" ] || exit 0

DIR="${CLAUDE_PROJECT_DIR:-$(json_field cwd)}"
[ -n "$DIR" ] && [ -d "$DIR" ] || DIR="$PWD"

# --- Is this a deploy? -------------------------------------------------------
S='[[:space:]]'
DEPLOY_RE="(^|[;&|(]|$S)("
DEPLOY_RE+="vercel($S+[^;&|]*)?$S--prod"
DEPLOY_RE+="|netlify$S+deploy[^;&|]*--prod"
DEPLOY_RE+="|(fly|flyctl)$S+deploy"
DEPLOY_RE+="|firebase$S+deploy"
DEPLOY_RE+="|wrangler$S+(pages$S+)?deploy"
DEPLOY_RE+="|railway$S+up"
DEPLOY_RE+="|gcloud$S+(app|run|functions)$S+deploy"
DEPLOY_RE+="|eb$S+deploy"
DEPLOY_RE+="|(serverless|sls|cdk|sam)$S+deploy"
DEPLOY_RE+="|amplify$S+publish"
DEPLOY_RE+="|(npm|pnpm|yarn|bun)$S+(run$S+)?deploy(:[a-z]+)?($S|$)"
DEPLOY_RE+="|git$S+push${S}[^;&|]*(heroku|dokku)"
DEPLOY_RE+=")"

is_deploy() {
  grep -qE "$DEPLOY_RE" <<<"$cmd" && return 0
  # git push to a production branch, or a bare push while on one.
  local seg refs=() w branch
  seg=$(grep -oE "git$S+push([^;&|]*)" <<<"$cmd" | head -n 1) || return 1
  for w in ${seg#*push}; do [[ "$w" == -* ]] || refs+=("$w"); done
  if [ ${#refs[@]} -ge 2 ]; then
    for w in "${refs[@]:1}"; do
      [[ "$w" =~ (^|:)(main|master|production|prod|release)$ ]] && return 0
    done
    return 1
  fi
  branch=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ "$branch" =~ ^(main|master|production|prod|release)$ ]]
}
is_deploy || exit 0

# --- Scan (or reuse a clean result for unchanged code) -----------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
SCANNER="$HERE/../skills/preflight/scripts/security-check.sh"
TMP="${TMPDIR:-/tmp}"
id=$(printf '%s' "$DIR" | cksum | cut -d' ' -f1)
LOG="$TMP/preflightkit-deploy-$id.log"
CACHE="$TMP/preflightkit-deploy-$id.ok"

state=""
if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  state=$( { git -C "$DIR" rev-parse HEAD; git -C "$DIR" diff HEAD --no-ext-diff;
             git -C "$DIR" ls-files --others --exclude-standard; echo "${PREFLIGHTKIT_DEPLOY_ARGS:-}"; } 2>/dev/null | cksum)
  [ -f "$CACHE" ] && [ "$(cat "$CACHE")" = "$state" ] && exit 0
fi

# shellcheck disable=SC2086  # PREFLIGHTKIT_DEPLOY_ARGS is a list of options
bash "$SCANNER" ${PREFLIGHTKIT_DEPLOY_ARGS:-} "$DIR" >"$LOG" 2>&1
code=$?

if [ "$code" -eq 0 ]; then
  [ -n "$state" ] && printf '%s' "$state" > "$CACHE"
  exit 0
fi
rm -f "$CACHE"

# --- Stop the deploy and say why ---------------------------------------------
results=$(sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -E '^ *\[(fail|error|warn)\]' | sed -E 's/^ *\[([a-z]+)\] */- [\1] /' | head -n 10)
if [ "$code" -eq 1 ]; then
  decision=deny; [ "$MODE" = "ask" ] && decision=ask
  reason="PreflightKit stopped this deploy: the security check found blocking issues.
$results
Full log: $LOG
Fix these first (the /preflightkit:security-review skill can help), then deploy again. Do not silence findings or lower the audit level to get past this check. If the user decides to accept the risk, they can deploy from their own terminal, or set PREFLIGHTKIT_DEPLOY_GATE=ask."
else
  decision=ask
  reason="PreflightKit could not fully check this deploy: a scanner failed to run, so part of the security check is missing.
$results
Full log: $LOG
Deploy anyway?"
fi

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/}"; s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
  "$decision" "$(json_escape "$reason")"
exit 0
