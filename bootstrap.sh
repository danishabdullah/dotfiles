#!/usr/bin/env bash
# --------------------------------------------------------------------
# Dotfiles bootstrapper: syncs repo contents into $HOME safely.
# Flags:
#   --force/-f       : skip confirmation prompt
#   --dry-run/-n     : show what would change without writing
#   --backup/-b <dir>: rsync backup dir for overwritten files
#   --no-brew        : skip running ./brew.sh before syncing
#   --macos          : run ./.macos after syncing (skipped on --dry-run)
# --------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--force|-f] [--dry-run|-n] [--backup|-b <dir>] [--no-brew] [--macos]
EOF
}

DRY_RUN=0
FORCE=0
BACKUP_DIR=""
NO_BREW=0
RUN_MACOS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -b|--backup)
      BACKUP_DIR="${2:-}"
      shift || true
      ;;
    --no-brew) NO_BREW=1 ;;
    --macos) RUN_MACOS=1 ;;
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
  if [[ $NO_BREW -ne 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Skipping brew.sh because --dry-run was requested"
    elif [[ -x ./brew.sh ]]; then
      echo "Running ./brew.sh (Homebrew bundle)..."
      ./brew.sh
    elif [[ -f ./brew.sh ]]; then
      echo "Running brew.sh via bash (not executable)..."
      bash ./brew.sh
    else
      echo "brew.sh not found; skipping Homebrew bundle." >&2
    fi
  fi

  local rsync_flags=(
    -avh
    --no-perms
    --exclude ".git/"
    --exclude ".DS_Store"
    --exclude "bootstrap.sh"
    --exclude "brew.sh"
    --exclude "brew-drift-report.sh"
    --exclude "install.sh"
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

  if [[ $RUN_MACOS -eq 1 ]]; then
    if [[ -x ./.macos ]]; then
      echo "Running ./.macos (may prompt for sudo)..."
      ./.macos
    elif [[ -f ./.macos ]]; then
      echo "Running ./.macos via bash (may prompt for sudo)..."
      bash ./.macos
    else
      echo ".macos not found; skipping macOS defaults." >&2
    fi
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
