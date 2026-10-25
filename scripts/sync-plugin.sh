#!/usr/bin/env bash
#
# sync-plugin.sh: copy the canonical docs and scanner into the skills pack.
#
# A plugin only ships the files inside its own folder, so each skill carries
# copies of the guides it needs. Edit the originals in docs/ and scripts/,
# then run this script. CI fails if the copies are out of date.
#
#   ./scripts/sync-plugin.sh          # update the copies
#   ./scripts/sync-plugin.sh --zip    # also build dist/*.zip for claude.ai upload

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SK="$ROOT/plugins/shipready/skills"

copy() { # copy <src> <dest>, adding a "generated" note to markdown files
  mkdir -p "$(dirname "$2")"
  if [[ "$1" == *.md ]]; then
    { printf '<!-- Generated from %s by scripts/sync-plugin.sh. Edit the original. -->\n\n' "${1#"$ROOT"/}"; cat "$1"; } > "$2"
  else
    cp "$1" "$2"
  fi
}

# security-review: checklist, every stack guide, scanner
rm -rf "$SK/security-review/references" "$SK/security-review/scripts"
copy "$ROOT/SECURITY-CHECKLIST.md" "$SK/security-review/references/checklist.md"
for f in "$ROOT"/docs/security/*.md; do
  [ "$(basename "$f")" = "README.md" ] && continue
  copy "$f" "$SK/security-review/references/stacks/$(basename "$f")"
done
copy "$ROOT/scripts/security-check.sh" "$SK/security-review/scripts/security-check.sh"

# ai-app-security: LLM guide and AI-assisted development guide
rm -rf "$SK/ai-app-security/references"
copy "$ROOT/docs/security/ai-llm-apps.md"        "$SK/ai-app-security/references/ai-llm-apps.md"
copy "$ROOT/docs/ai-assisted-development.md"     "$SK/ai-app-security/references/ai-assisted-development.md"

# preflight: one checklist per pillar, scanner
rm -rf "$SK/preflight/references" "$SK/preflight/scripts"
copy "$ROOT/SECURITY-CHECKLIST.md"               "$SK/preflight/references/security-checklist.md"
copy "$ROOT/docs/ux-accessibility/README.md"     "$SK/preflight/references/ux-accessibility.md"
copy "$ROOT/docs/database/README.md"             "$SK/preflight/references/database.md"
copy "$ROOT/scripts/security-check.sh"           "$SK/preflight/scripts/security-check.sh"

chmod +x "$SK"/*/scripts/*.sh 2>/dev/null || true
echo "Synced skill references into plugins/shipready/skills/"

# Optional: one zip per skill, for upload in claude.ai (Settings > Features).
if [ "${1:-}" = "--zip" ]; then
  mkdir -p "$ROOT/dist"
  for d in "$SK"/*/; do
    name="$(basename "$d")"
    rm -f "$ROOT/dist/shipready-$name.zip"
    ( cd "$SK" && zip -qr "$ROOT/dist/shipready-$name.zip" "$name" )
    echo "  dist/shipready-$name.zip"
  done
fi
