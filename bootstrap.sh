#!/usr/bin/env bash
# --------------------------------------------------------------------
# Dotfiles bootstrapper: syncs repo contents into $HOME safely.
# Flags:
#   --force/-f   : skip confirmation prompt
#   --dry-run/-n : show what would change without writing
#   --backup/-b <dir> : rsync backup dir for overwritten files
# --------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--force|-f] [--dry-run|-n] [--backup|-b <dir>]
EOF
}

DRY_RUN=0
FORCE=0
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -b|--backup)
      BACKUP_DIR="${2:-}"
      shift || true
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

command -v rsync >/dev/null 2>&1 || { echo "rsync is required" >&2; exit 1; }

doIt() {
  local rsync_flags=(
    -avh
    --no-perms
    --exclude ".git/"
    --exclude ".DS_Store"
    --exclude ".osx"
    --exclude "bootstrap.sh"
    --exclude "README.md"
    --exclude "LICENSE-MIT.txt"
  )

  if [[ -n "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    rsync_flags+=(--backup --backup-dir="$BACKUP_DIR")
  fi

  [[ $DRY_RUN -eq 1 ]] && rsync_flags+=(-n)

  rsync "${rsync_flags[@]}" . ~

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run only; no files changed)"
    return
  fi

  echo "Sync complete. Reload your shell or run: source ~/.bash_profile"
}

if [[ $FORCE -eq 1 ]]; then
  doIt
else
  read -p "This may overwrite existing files in your home directory. Proceed? (y/n) " -n 1
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    doIt
  else
    echo "Aborted."
  fi
fi

unset -f doIt usage
