#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

force=false
if [[ "${1-}" == "--force" || "${1-}" == "-f" ]]; then
  force=true
fi

confirm() {
  if "$force"; then
    return 0
  fi

  read -r -p "This will delete ignored/build artifacts. Continue? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

if command -v git >/dev/null 2>&1 && [[ -d "$root_dir/.git" ]]; then
  echo "Using git clean to remove ignored files."
  if confirm; then
    (cd "$root_dir" && git clean -fdX)
  else
    echo "Cleanup canceled."
  fi
  exit 0
fi

echo "Git not available; removing common build artifacts."
if ! confirm; then
  echo "Cleanup canceled."
  exit 0
fi

shopt -s nullglob

patterns=(
  "node_modules"
  "dist"
  "out"
  "electron/R-portable"
  "temp_r_download"
  ".tmp"
  "lint.log"
  "npm-debug.log*"
  "yarn-debug.log*"
  "yarn-error.log*"
  "*.blockmap"
  "*.dmg"
  "*.exe"
  "*.AppImage"
  "*.deb"
  "*.zip"
  "*.tar.gz"
  "*.Rcheck"
  "docs"
  ".Rproj.user"
  "rsconnect"
  "vignettes/*.html"
  "vignettes/*.pdf"
  ".Rhistory"
  ".Rapp.history"
  ".RData"
  ".RDataTmp"
  ".Ruserdata"
  ".Renviron"
  "package-lock.json"
  "package-shiny.json"
  "cache"
  "*_cache"
  "*.utf8.md"
  "*.knit.md"
  ".DS_Store"
  "Thumbs.db"
)

for pattern in "${patterns[@]}"; do
  rm -rf "$root_dir"/$pattern
done

echo "Cleanup complete."
