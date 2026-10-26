#!/usr/bin/env bash
# Assemble a clean, machine-independent open-source repository from the local
# working tree. This script only COPIES and mechanically generalizes paths; it
# never embeds credentials. Run from anywhere.
set -euo pipefail

SRC=/d/automate
REPO=/d/wang-ai-workbench

rm -rf "$REPO"
mkdir -p "$REPO"/desktop "$REPO"/console "$REPO"/platform "$REPO"/brand "$REPO"/docs

copy() { # copy <src> <dst>
  if [ -e "$1" ]; then cp -r "$1" "$2"; else echo "skip(missing): $1"; fi
}

# --- desktop app + installer (source only) ---
copy "$SRC/desktop/WangDesktop"  "$REPO/desktop/WangDesktop"
copy "$SRC/desktop/WangInstaller" "$REPO/desktop/WangInstaller"
copy "$SRC/relay.js"            "$REPO/desktop/relay.js"
copy "$SRC/desktop/wang-service-start.bat" "$REPO/desktop/wang-service-start.bat"

# --- console service ---
copy "$SRC/wang/wang_service.py" "$REPO/console/wang_service.py"
copy "$SRC/wang/start.sh"        "$REPO/console/start.sh"

# --- platform tooling ---
copy "$SRC/wsl/patch_magpie.py"  "$REPO/platform/patch_magpie.py"
copy "$SRC/wsl/fix_catalog.py"   "$REPO/platform/fix_catalog.py"
copy "$SRC/wsl/fix_llmmodels.py" "$REPO/platform/fix_llmmodels.py"
copy "$SRC/brand/nginx_patch.py" "$REPO/platform/nginx_patch.py"
copy "$SRC/wang/nginx_route.py"  "$REPO/platform/nginx_route.py"

# --- brand assets + front-end patch tooling ---
for f in logo.svg favicon.svg wang-wordmark.svg make_logos.py make_ico.py \
         theme_tokens.py patch_brand.py patch_sidebar.py patch_free.py \
         rename_chunks.py restore_names.py patch_bundle.py zh-cn.json apply.sh; do
  copy "$SRC/brand/$f" "$REPO/brand/$f"
done
# make_ico.py and the i18n bundle patcher live outside brand/ in the working tree
copy "$SRC/desktop/make_ico.py" "$REPO/brand/make_ico.py"
copy "$SRC/i18n/patch_bundle.py" "$REPO/brand/patch_bundle.py"
copy "$SRC/i18n/zh-cn.json"      "$REPO/brand/zh-cn.json"

# --- strip build outputs / binaries ---
find "$REPO" -type d \( -name bin -o -name obj -o -name publish -o -name payload \
     -o -name installer-payload -o -name node_modules -o -name .vs \) -prune -exec rm -rf {} + 2>/dev/null || true
find "$REPO" -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.png' -o -name '*.ico' \) -delete 2>/dev/null || true

# --- generalize absolute machine paths in shell tooling ---
# Every operator script resolves the repo root from its own location, so the
# checkout can live anywhere on any machine.
while IFS= read -r sh; do
  # inject WANG_ROOT right after the shebang if not present
  if ! grep -q 'WANG_ROOT=' "$sh"; then
    awk 'NR==1{print; print "WANG_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/..\" && pwd)\""; next} {print}' "$sh" > "$sh.tmp" \
      && mv "$sh.tmp" "$sh"
  fi
  sed -i \
    -e 's#/mnt/d/automate#$WANG_ROOT#g' \
    -e 's#/d/automate#$WANG_ROOT#g' \
    "$sh"
done < <(find "$REPO" -name '*.sh' -type f)

# --- scrub any residual personal identifiers from copied sources ---
grep -rlI 'coldcoffee' "$REPO" 2>/dev/null | while IFS= read -r f; do
  sed -i '/coldcoffee/d' "$f"
done

echo "REPO_ASSEMBLED at $REPO"
find "$REPO" -maxdepth 2 -type d | sort
