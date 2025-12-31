#!/usr/bin/env bash
# --------------------------------------------------------------------
# Dotfiles bootstrapper: syncs repo contents into $HOME safely.
# Flags:
#   --force/-f       : skip confirmation prompt
#   --dry-run/-n     : show what would change without writing
#   --backup/-b <dir>: rsync backup dir for overwritten files
#   --no-brew        : skip running ./brew.sh before syncing
#   --no-apt         : skip running ./apt.sh before syncing (Debian/Ubuntu only)
#   --apt-desktop    : include Aptfile.desktop packages (Debian/Ubuntu only)
#   --apt-setup-repos: set up external apt repos (Caddy + Azure CLI + PostgreSQL)
#   --no-shell       : skip setting default shell to latest bash
#   --macos          : run ./.macos after syncing (skipped on --dry-run)
# --------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--force|-f] [--dry-run|-n] [--backup|-b <dir>] [--no-brew] [--no-apt] [--apt-desktop] [--apt-setup-repos] [--no-fonts] [--default-font NAME] [--no-shell] [--macos]
EOF
}

DRY_RUN=0
FORCE=0
BACKUP_DIR=""
NO_BREW=0
NO_APT=0
APT_DESKTOP=0
APT_SETUP_REPOS=0
NO_FONTS=0
DEFAULT_FONT=""
RUN_MACOS=0
SET_SHELL=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -b|--backup)
      BACKUP_DIR="${2:-}"
      shift || true
      ;;
    --no-brew) NO_BREW=1 ;;
    --no-apt) NO_APT=1 ;;
    --apt-desktop) APT_DESKTOP=1 ;;
    --apt-setup-repos) APT_SETUP_REPOS=1 ;;
    --no-fonts) NO_FONTS=1 ;;
    --default-font)
      [[ -z "${2:-}" || "$2" == -* ]] && { echo "--default-font requires a font name" >&2; exit 1; }
      DEFAULT_FONT="$2"
      shift
      ;;
    --macos) RUN_MACOS=1 ;;
    --no-shell) SET_SHELL=0 ;;
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

  if [[ $NO_APT -ne 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Skipping apt.sh because --dry-run was requested"
    elif [[ "$(uname -s)" == "Linux" ]] && [[ -r /etc/os-release ]] && grep -qEi '^(ID|ID_LIKE)=.*debian' /etc/os-release; then
      if [[ -x ./apt.sh ]]; then
        echo "Running ./apt.sh (Aptfile packages)..."
        if [[ $APT_DESKTOP -eq 1 && $APT_SETUP_REPOS -eq 1 ]]; then
          ./apt.sh --desktop --setup-repos
        elif [[ $APT_DESKTOP -eq 1 ]]; then
          ./apt.sh --desktop
        elif [[ $APT_SETUP_REPOS -eq 1 ]]; then
          ./apt.sh --setup-repos
        else
          ./apt.sh
        fi
      elif [[ -f ./apt.sh ]]; then
        echo "Running apt.sh via bash (not executable)..."
        if [[ $APT_DESKTOP -eq 1 && $APT_SETUP_REPOS -eq 1 ]]; then
          bash ./apt.sh --desktop --setup-repos
        elif [[ $APT_DESKTOP -eq 1 ]]; then
          bash ./apt.sh --desktop
        elif [[ $APT_SETUP_REPOS -eq 1 ]]; then
          bash ./apt.sh --setup-repos
        else
          bash ./apt.sh
        fi
      else
        echo "apt.sh not found; skipping Aptfile packages." >&2
      fi
    fi
  fi

  # Install Nerd Fonts on Linux
  if [[ $NO_FONTS -ne 1 ]] && [[ "$(uname -s)" == "Linux" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "Skipping fonts.sh because --dry-run was requested"
    elif [[ -x ./fonts.sh ]] || [[ -f ./fonts.sh ]]; then
      echo "Running ./fonts.sh (Nerd Fonts)..."
      local font_args=()
      if [[ -n "$DEFAULT_FONT" ]]; then
        font_args+=(--default "$DEFAULT_FONT")
      fi
      if [[ -x ./fonts.sh ]]; then
        ./fonts.sh "${font_args[@]}"
      else
        bash ./fonts.sh "${font_args[@]}"
      fi
    else
      echo "fonts.sh not found; skipping Nerd Fonts." >&2
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
    --exclude "apt.sh"
    --exclude "apt-repos.sh"
    --exclude "fonts.sh"
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

  # Update default shell to latest bash (best-effort)
  if [[ $SET_SHELL -eq 1 ]]; then
    bash_path=""
    if [[ "$(uname -s)" == "Darwin" ]]; then
      if [[ -x /opt/homebrew/bin/bash ]]; then
        bash_path="/opt/homebrew/bin/bash"
      elif [[ -x /usr/local/bin/bash ]]; then
        bash_path="/usr/local/bin/bash"
      fi
    fi
    if [[ -z "$bash_path" ]]; then
      bash_path="$(command -v bash 2>/dev/null || true)"
    fi

    if [[ -n "$bash_path" && "${SHELL:-}" != "$bash_path" && -x "$bash_path" ]]; then
      if [[ $FORCE -eq 1 ]]; then
        if [[ -f /etc/shells ]] && ! grep -qx "$bash_path" /etc/shells; then
          echo "$bash_path" | sudo tee -a /etc/shells >/dev/null || true
        fi
        chsh -s "$bash_path" || true
      else
        read -p "Change default shell to $bash_path? (y/n) " -n 1
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          if [[ -f /etc/shells ]] && ! grep -qx "$bash_path" /etc/shells; then
            echo "$bash_path" | sudo tee -a /etc/shells >/dev/null || true
          fi
          chsh -s "$bash_path" || true
        fi
      fi
    fi
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
