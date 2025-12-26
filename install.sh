#!/usr/bin/env bash
# shellcheck shell=bash
#
# Dotfiles Installer
# https://github.com/danishabdullah/dotfiles
#
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/danishabdullah/dotfiles/master/install.sh)"
#
# Options (pass as environment variables or CLI flags - see --help for details):
#   DOTFILES_FORCE=1     - Skip confirmation prompts (auto-yes to all)
#   DOTFILES_DRY_RUN=1   - Preview changes without writing
#   DOTFILES_BACKUP=path - Backup existing files to this directory
#   DOTFILES_NO_BREW=1   - Skip Homebrew bundle installation
#   DOTFILES_MACOS=1     - Apply macOS system defaults
#   DOTFILES_BRANCH=name - Use a specific branch (default: master)
#   DOTFILES_STRICT=1    - Exit with error if any warnings occur
#
set -euo pipefail

# Prevent sourcing - this script must be executed, not sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script must be executed, not sourced" >&2
    return 1
fi

# Configuration (can be overridden via environment or CLI flags)
GITHUB_USER="${GITHUB_USER:-danishabdullah}"
GITHUB_REPO="${GITHUB_REPO:-dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"
VERSION="1.6.0"

# Validate HOME is set (critical for the script to work)
if [[ -z "${HOME:-}" ]]; then
    echo "Error: HOME environment variable is not set" >&2
    exit 1
fi

# Computed after args are parsed
TARBALL_URL=""

# Cache uname result
OS_TYPE="$(uname)"

# Temp directory for downloads (cleaned up on exit)
TMPDIR_INSTALL=""

# Track warnings/errors for final summary
INSTALL_WARNINGS=()

# Track if .ssh was synced (for permission fix)
SSH_WAS_SYNCED=0

# Track sync stats
SYNC_STATS=""

# Backup timestamp (set once for consistent naming)
BACKUP_TIMESTAMP=""

# Centralized exclusion list (used by both check_overwrites and rsync)
EXCLUDE_FILES=(".git" ".DS_Store" "bootstrap.sh" "brew.sh" "brew-drift-report.sh" "install.sh" "README.md" "LICENSE-MIT.txt")

# Colors for output (disabled if stderr is not a TTY)
# All logging goes to stderr to keep stdout clean for data/return values
if [[ -t 2 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Logging functions (all output to stderr to keep stdout clean for data)
info() { echo -e "${BLUE}==>${NC} ${BOLD}$*${NC}" >&2; }
success() { echo -e "${GREEN}==>${NC} ${BOLD}$*${NC}" >&2; }
warn() {
    echo -e "${YELLOW}Warning:${NC} $*" >&2
    INSTALL_WARNINGS+=("$*")
}
error() { echo -e "${RED}Error:${NC} $*" >&2; }
abort() { error "$@"; exit 1; }

# Cleanup function
cleanup() {
    if [[ -n "$TMPDIR_INSTALL" && -d "$TMPDIR_INSTALL" ]]; then
        rm -rf "$TMPDIR_INSTALL"
    fi
}

# Set up signal handlers
trap cleanup EXIT
trap 'echo ""; error "Interrupted"; exit 130' INT
trap 'error "Terminated"; exit 143' TERM

# Show help
show_help() {
    cat <<EOF
Dotfiles Installer v${VERSION}

Usage:
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${DOTFILES_BRANCH}/install.sh)"

Environment Variables:
  DOTFILES_FORCE=1       Skip all confirmation prompts (auto-yes to all)
  DOTFILES_DRY_RUN=1     Preview changes without writing anything
  DOTFILES_BACKUP=<dir>  Backup overwritten files to specified directory
  DOTFILES_NO_BREW=1     Skip Homebrew package installation
  DOTFILES_MACOS=1       Apply macOS system defaults (requires sudo)
  DOTFILES_BRANCH=<name> Use a specific branch (default: master)
  DOTFILES_STRICT=1      Exit with error code if any warnings occur
  GITHUB_USER=<user>     Use a different GitHub user (default: danishabdullah)
  GITHUB_REPO=<repo>     Use a different repo name (default: dotfiles)

Command Line Options:
  -h, --help               Show this help message
  -V, --version            Show version number
  -f, --force              Skip all confirmation prompts (auto-yes to all)
  -n, --dry-run            Preview changes without writing anything
  -b, --backup <dir>       Backup overwritten files to specified directory
  --branch <name>          Use a specific branch (default: master)
  --user <name>            Use a different GitHub user
  --repo <name>            Use a different repo name
  --no-brew                Skip Homebrew package installation
  --macos                  Apply macOS system defaults (requires sudo)
  --strict                 Exit with error code if any warnings occur

Examples:
  # Dry run to preview changes
  ./install.sh --dry-run

  # Force install with backup
  ./install.sh --force --backup ~/dotfiles-backup

  # Install from a different branch
  ./install.sh --branch dev

  # Install from a fork
  ./install.sh --user myusername --repo mydotfiles

  # Non-interactive install, skip Homebrew
  DOTFILES_FORCE=1 DOTFILES_NO_BREW=1 /bin/bash -c "\$(curl -fsSL ...)"

  # CI/automation with strict mode (fail on warnings)
  DOTFILES_FORCE=1 DOTFILES_STRICT=1 ./install.sh

EOF
    exit 0
}

# Show version
show_version() {
    echo "Dotfiles Installer v${VERSION}" >&2
    exit 0
}

# Validate GitHub identifier (user, repo, or branch name)
# Allows: alphanumeric, dash, underscore, dot, forward slash (for branches)
validate_github_identifier() {
    local name="$1"
    local value="$2"
    local allow_slash="${3:-0}"

    if [[ -z "$value" ]]; then
        abort "$name cannot be empty"
    fi

    local pattern='^[a-zA-Z0-9._-]+$'
    if [[ "$allow_slash" == "1" ]]; then
        pattern='^[a-zA-Z0-9._/-]+$'
    fi

    if [[ ! "$value" =~ $pattern ]]; then
        abort "$name contains invalid characters: $value (allowed: a-z, A-Z, 0-9, ., _, -${allow_slash:+, /})"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help ;;
            -V|--version) show_version ;;
            -f|--force) export DOTFILES_FORCE=1 ;;
            -n|--dry-run) export DOTFILES_DRY_RUN=1 ;;
            --no-brew) export DOTFILES_NO_BREW=1 ;;
            --macos) export DOTFILES_MACOS=1 ;;
            --strict) export DOTFILES_STRICT=1 ;;
            --branch)
                [[ -z "${2:-}" || "$2" == -* ]] && abort "--branch requires a branch name"
                DOTFILES_BRANCH="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" || "$2" == -* ]] && abort "--user requires a username"
                GITHUB_USER="$2"
                shift
                ;;
            --repo)
                [[ -z "${2:-}" || "$2" == -* ]] && abort "--repo requires a repo name"
                GITHUB_REPO="$2"
                shift
                ;;
            -b|--backup)
                [[ -z "${2:-}" || "$2" == -* ]] && abort "--backup requires a directory path"
                export DOTFILES_BACKUP="$2"
                shift
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
        shift
    done

    # Validate identifiers
    validate_github_identifier "GitHub user" "$GITHUB_USER" 0
    validate_github_identifier "GitHub repo" "$GITHUB_REPO" 0
    validate_github_identifier "Branch name" "$DOTFILES_BRANCH" 1  # allow / for branches like feature/foo

    # Set tarball URL after all args are parsed
    TARBALL_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/refs/heads/${DOTFILES_BRANCH}.tar.gz"
}

# Check if running interactively
is_interactive() {
    [[ -t 0 && -t 1 ]]
}

# Unified prompt function
# Usage: prompt "question" "default" "required"
#   default: "y" or "n"
#   required: if "1", exits in non-interactive without FORCE; if "0", returns 1 instead
prompt_confirm() {
    local question="$1"
    local default="${2:-n}"
    local required="${3:-1}"

    # FORCE mode: auto-yes
    if [[ "${DOTFILES_FORCE:-}" == "1" ]]; then
        return 0
    fi

    # Non-interactive handling
    if ! is_interactive; then
        if [[ "$required" == "1" ]]; then
            error "Non-interactive mode requires DOTFILES_FORCE=1 to proceed"
            error "Prompt was: $question"
            exit 1
        else
            return 1
        fi
    fi

    # Interactive prompt
    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$question [Y/n] " yn
        yn="${yn:-y}"
    else
        read -rp "$question [y/N] " yn
        yn="${yn:-n}"
    fi

    [[ "$yn" =~ ^[Yy] ]]
}

# Shortcuts for common cases
confirm() { prompt_confirm "$1" "${2:-n}" "1"; }
confirm_optional() { prompt_confirm "$1" "${2:-n}" "0"; }

# Check for required commands
check_requirements() {
    local missing=()

    for cmd in curl tar rsync; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        abort "Missing required commands: ${missing[*]}"
    fi
}

# Install Homebrew if not present
install_homebrew() {
    if command -v brew &>/dev/null; then
        info "Homebrew is already installed"
        return 0
    fi

    if [[ "$OS_TYPE" != "Darwin" ]]; then
        warn "Homebrew installation skipped (not macOS)"
        info "On Linux, install packages manually or use your distro's package manager"
        return 0
    fi

    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL --connect-timeout 10 --max-time 300 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# Download and extract dotfiles
download_dotfiles() {
    # Create temp directory - set in global scope for cleanup
    TMPDIR_INSTALL="$(mktemp -d)" || abort "Failed to create temporary directory"

    if [[ -z "$TMPDIR_INSTALL" || ! -d "$TMPDIR_INSTALL" ]]; then
        abort "Failed to create temporary directory"
    fi

    info "Downloading dotfiles from ${TARBALL_URL}..."

    local archive_file="$TMPDIR_INSTALL/archive.tar.gz"

    # Download with progress indicator for interactive mode
    local curl_opts=(--connect-timeout 10 --max-time 120 -fL -o "$archive_file")
    if is_interactive; then
        # Progress bar (writes to stderr)
        curl_opts+=(-#)
    else
        # Silent mode (no progress, no errors - we handle errors via get_download_error)
        curl_opts+=(-s)
    fi

    if ! curl "${curl_opts[@]}" "$TARBALL_URL"; then
        get_download_error
    fi

    if [[ ! -s "$archive_file" ]]; then
        abort "Downloaded archive is empty"
    fi

    info "Extracting archive..."
    if ! tar -xzf "$archive_file" -C "$TMPDIR_INSTALL"; then
        abort "Failed to extract dotfiles archive"
    fi
    rm -f "$archive_file"

    # Find the extracted directory (github adds repo-branch suffix)
    local extracted_dir=""
    local dir_count=0

    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        extracted_dir="$dir"
        ((dir_count++))
    done < <(find "$TMPDIR_INSTALL" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [[ "$dir_count" -eq 0 ]]; then
        abort "No directory found in downloaded archive"
    elif [[ "$dir_count" -gt 1 ]]; then
        abort "Unexpected: multiple directories in archive"
    fi

    if [[ -z "$extracted_dir" || ! -d "$extracted_dir" ]]; then
        abort "Extracted directory is invalid"
    fi

    echo "$extracted_dir"
}

# Helper to provide specific download error
get_download_error() {
    local http_code
    http_code=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TARBALL_URL" 2>/dev/null || echo "000")
    case "$http_code" in
        404) abort "Repository or branch not found (404). Check --user='$GITHUB_USER', --repo='$GITHUB_REPO', --branch='$DOTFILES_BRANCH'" ;;
        000) abort "Network error: could not connect to GitHub. Check your internet connection." ;;
        *)   abort "Failed to download dotfiles (HTTP $http_code). Check your network connection." ;;
    esac
}

# Check for files that will be overwritten
# Returns: 0 if no overwrites or user confirmed, exits if user declines
check_overwrites() {
    local source_dir="$1"
    local overwrites=()

    # Check all files that exist in both source and home
    while IFS= read -r -d '' file; do
        local relative="${file#$source_dir/}"

        # Skip excluded files
        local skip=0
        for exclude in "${EXCLUDE_FILES[@]}"; do
            if [[ "$relative" == "$exclude" || "$relative" == "$exclude"/* ]]; then
                skip=1
                break
            fi
        done
        [[ "$skip" -eq 1 ]] && continue

        if [[ -e "$HOME/$relative" ]]; then
            overwrites+=("$relative")
        fi
    done < <(find "$source_dir" -type f -print0 2>/dev/null)

    # Track if .ssh will be synced
    if [[ -d "$source_dir/.ssh" ]]; then
        SSH_WAS_SYNCED=1
    fi

    if [[ ${#overwrites[@]} -eq 0 ]]; then
        info "No existing files will be overwritten"
        return 0
    fi

    # Show what will be overwritten (always, even with FORCE)
    local count=${#overwrites[@]}
    echo >&2
    echo -e "${YELLOW}$count file(s) will be overwritten:${NC}" >&2
    if [[ $count -le 15 ]]; then
        for f in "${overwrites[@]}"; do
            echo "    $f" >&2
        done
    else
        for f in "${overwrites[@]:0:10}"; do
            echo "    $f" >&2
        done
        echo "    ... and $((count - 10)) more" >&2
    fi
    echo >&2

    if [[ -z "${DOTFILES_BACKUP:-}" ]]; then
        info "Tip: Use --backup <dir> to backup existing files"
        echo >&2
    fi

    # With FORCE, we showed the warning but continue automatically
    if [[ "${DOTFILES_FORCE:-}" == "1" ]]; then
        info "Proceeding (--force specified)"
        return 0
    fi

    # Without FORCE, ask for confirmation
    if ! prompt_confirm "Proceed with overwriting these files?" "y" "1"; then
        abort "Installation cancelled by user"
    fi
}

# Expand tilde in path safely (no eval)
expand_tilde() {
    local path="$1"

    case "$path" in
        "~")
            echo "$HOME"
            ;;
        "~"/*)
            echo "${HOME}${path:1}"
            ;;
        "~"*)
            # ~user or ~user/path format
            local tilde_prefix="${path%%/*}"  # ~user
            local username="${tilde_prefix:1}"  # user (remove ~)
            local rest="${path:${#tilde_prefix}}"  # /path or empty

            # Look up user's home directory
            local user_home=""
            if command -v getent &>/dev/null; then
                user_home="$(getent passwd "$username" 2>/dev/null | cut -d: -f6)"
            elif [[ -r /etc/passwd ]]; then
                user_home="$(awk -F: -v u="$username" '$1 == u {print $6}' /etc/passwd 2>/dev/null)"
            fi

            if [[ -n "$user_home" ]]; then
                echo "${user_home}${rest}"
            else
                # Can't expand, return as-is
                echo "$path"
            fi
            ;;
        *)
            echo "$path"
            ;;
    esac
}

# Resolve and validate backup directory path
resolve_backup_dir() {
    local backup_dir="$1"

    # Expand tilde first
    backup_dir="$(expand_tilde "$backup_dir")"

    # Resolve to absolute path
    if [[ "$backup_dir" != /* ]]; then
        local parent_dir base_name
        parent_dir="$(dirname "$backup_dir")"
        base_name="$(basename "$backup_dir")"

        if [[ -d "$parent_dir" ]]; then
            backup_dir="$(cd "$parent_dir" && pwd)/$base_name"
        elif [[ "$parent_dir" == "." ]]; then
            backup_dir="$PWD/$base_name"
        else
            abort "Backup directory parent does not exist: $parent_dir"
        fi
    fi

    echo "$backup_dir"
}

# Sync dotfiles to home directory
sync_dotfiles() {
    local source_dir="$1"
    local dry_run="${DOTFILES_DRY_RUN:-}"
    local backup_dir="${DOTFILES_BACKUP:-}"

    # Base rsync options
    local rsync_opts=(-ah --no-perms)

    # Add verbosity for interactive or dry-run
    if is_interactive || [[ "$dry_run" == "1" ]]; then
        rsync_opts+=(-v --stats)
    fi

    # Add excludes from centralized list (build array directly, no word splitting)
    for exclude in "${EXCLUDE_FILES[@]}"; do
        if [[ "$exclude" == ".git" ]]; then
            rsync_opts+=(--exclude=".git/")
        else
            rsync_opts+=("--exclude=$exclude")
        fi
    done

    if [[ "$dry_run" == "1" ]]; then
        rsync_opts+=(--dry-run)
        info "Dry run mode - showing what would be synced..."
    fi

    if [[ -n "$backup_dir" ]]; then
        backup_dir="$(resolve_backup_dir "$backup_dir")"

        # Use timestamp suffix for backups to avoid overwrites on re-runs
        if [[ -z "$BACKUP_TIMESTAMP" ]]; then
            BACKUP_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        fi

        mkdir -p "$backup_dir"
        rsync_opts+=(--backup "--backup-dir=$backup_dir" "--suffix=.bak_${BACKUP_TIMESTAMP}")
        info "Backing up overwritten files to: $backup_dir (suffix: .bak_${BACKUP_TIMESTAMP})"
    fi

    info "Syncing dotfiles to $HOME..."

    # Capture rsync output
    local rsync_output
    if rsync_output=$(rsync "${rsync_opts[@]}" "$source_dir/" "$HOME/" 2>&1); then
        # Show output first (before success message)
        # Use cat -s to squeeze multiple blank lines into one (preserves structure)
        if is_interactive || [[ "$dry_run" == "1" ]]; then
            echo "$rsync_output" | cat -s >&2
            echo >&2
        fi

        if [[ "$dry_run" != "1" ]]; then
            # Extract stats if available
            if [[ "$rsync_output" == *"Number of"* ]]; then
                SYNC_STATS=$(echo "$rsync_output" | grep -E "Number of|Total file size|Total transferred|Literal data|Matched data")
            fi
            success "Dotfiles synced successfully!"
        fi
    else
        abort "Rsync failed: $rsync_output"
    fi
}

# Fix SSH directory permissions (only if we synced .ssh)
fix_ssh_permissions() {
    if [[ "$SSH_WAS_SYNCED" -ne 1 ]]; then
        return 0
    fi

    if [[ -d "$HOME/.ssh" ]]; then
        chmod 700 "$HOME/.ssh"
        find "$HOME/.ssh" -type f -exec chmod 600 {} \; 2>/dev/null || true
        info "SSH directory permissions set (700 for dir, 600 for files)"
    fi
}

# Run Homebrew bundle
run_brew_bundle() {
    if [[ "${DOTFILES_NO_BREW:-}" == "1" ]]; then
        info "Skipping Homebrew bundle (DOTFILES_NO_BREW=1)"
        return 0
    fi

    if [[ "$OS_TYPE" != "Darwin" ]]; then
        info "Skipping Homebrew bundle on non-macOS"
        if [[ "$OS_TYPE" == "Linux" ]]; then
            info "Debian/Ubuntu hint: install packages via apt (Aptfile support not yet wired)"
        fi
        return 0
    fi

    if ! command -v brew &>/dev/null; then
        warn "Homebrew not found, skipping bundle installation"
        return 0
    fi

    if [[ ! -f "$HOME/Brewfile" ]]; then
        warn "No Brewfile found in home directory, skipping bundle"
        return 0
    fi

    if ! confirm_optional "Install Homebrew packages from Brewfile?" "y"; then
        info "Skipping Homebrew bundle"
        return 0
    fi

    info "Running Homebrew bundle..."
    if ! brew update; then
        warn "brew update failed, continuing anyway..."
    fi

    if ! brew bundle install --file="$HOME/Brewfile" --no-lock; then
        warn "Some Homebrew packages failed to install"
        return 0
    fi

    brew cleanup 2>/dev/null || true
    success "Homebrew packages installed!"
}

# Preview Homebrew bundle entries without installing
print_brew_plan() {
    local brewfile="$1"

    if [[ "${DOTFILES_NO_BREW:-}" == "1" ]]; then
        info "Skipping Homebrew bundle preview (DOTFILES_NO_BREW=1)"
        return 0
    fi

    if [[ ! -f "$brewfile" ]]; then
        warn "No Brewfile found at $brewfile, skipping Homebrew preview"
        return 0
    fi

    local taps=()
    local brews=()
    local casks=()
    local mas=()
    local other=()
    local line kind name

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

        if [[ "$line" =~ ^([a-zA-Z_]+)[[:space:]]+\"([^\"]+)\" ]]; then
            kind="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([a-zA-Z_]+)[[:space:]]+\'([^\']+)\' ]]; then
            kind="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
        else
            continue
        fi

        case "$kind" in
            tap) taps+=("$name") ;;
            brew) brews+=("$name") ;;
            cask) casks+=("$name") ;;
            mas) mas+=("$name") ;;
            *) other+=("$kind:$name") ;;
        esac
    done < "$brewfile"

    info "Homebrew bundle preview (dry run)"
    if [[ ${#taps[@]} -gt 0 ]]; then
        echo "  Taps (${#taps[@]}):" >&2
        for item in "${taps[@]}"; do
            echo "    - $item" >&2
        done
    fi
    if [[ ${#brews[@]} -gt 0 ]]; then
        echo "  Formulae (${#brews[@]}):" >&2
        for item in "${brews[@]}"; do
            echo "    - $item" >&2
        done
    fi
    if [[ ${#casks[@]} -gt 0 ]]; then
        echo "  Casks (${#casks[@]}):" >&2
        for item in "${casks[@]}"; do
            echo "    - $item" >&2
        done
    fi
    if [[ ${#mas[@]} -gt 0 ]]; then
        echo "  Mac App Store (${#mas[@]}):" >&2
        for item in "${mas[@]}"; do
            echo "    - $item" >&2
        done
    fi
    if [[ ${#other[@]} -gt 0 ]]; then
        echo "  Other (${#other[@]}):" >&2
        for item in "${other[@]}"; do
            echo "    - $item" >&2
        done
    fi
}

# Apply macOS defaults
apply_macos_defaults() {
    if [[ "${DOTFILES_MACOS:-}" != "1" ]]; then
        return 0
    fi

    if [[ "$OS_TYPE" != "Darwin" ]]; then
        warn "macOS defaults can only be applied on macOS"
        return 0
    fi

    if [[ ! -f "$HOME/.macos" ]]; then
        warn "No .macos file found, skipping system defaults"
        return 0
    fi

    if ! confirm_optional "Apply macOS system defaults? (requires sudo)" "n"; then
        info "Skipping macOS defaults"
        return 0
    fi

    info "Applying macOS defaults..."
    chmod +x "$HOME/.macos"
    if ! "$HOME/.macos"; then
        warn "Some macOS defaults may have failed to apply"
    else
        success "macOS defaults applied! Some changes require a logout/restart."
    fi
}

# Print post-installation message
# Returns: 0 on success, 1 if warnings occurred and strict mode is enabled
print_postinstall() {
    echo >&2
    success "Installation complete!"

    # Show sync stats if available
    if [[ -n "$SYNC_STATS" ]]; then
        echo >&2
        echo "$SYNC_STATS" >&2
    fi

    # Show any warnings that occurred
    local has_warnings=0
    if [[ ${#INSTALL_WARNINGS[@]} -gt 0 ]]; then
        has_warnings=1
        echo >&2
        echo -e "${YELLOW}Warnings during installation:${NC}" >&2
        for warning in "${INSTALL_WARNINGS[@]}"; do
            echo "  - $warning" >&2
        done
    fi

    echo >&2
    info "Next steps:"
    echo "  1. Start a new shell or run: source ~/.bash_profile" >&2
    echo "  2. Create ~/.extra for machine-specific settings (not tracked by git)" >&2
    echo "  3. Customize ~/.path for additional PATH entries" >&2
    echo >&2
    if [[ "$OS_TYPE" == "Darwin" && "${DOTFILES_MACOS:-}" != "1" ]]; then
        echo "  For macOS system defaults, run: ~/.macos" >&2
        echo >&2
    fi

    echo -e "Installed from: ${BLUE}github.com/${GITHUB_USER}/${GITHUB_REPO}@${DOTFILES_BRANCH}${NC}" >&2
    echo -e "Installer version: ${BLUE}${VERSION}${NC}" >&2

    # In strict mode, exit with error if there were warnings
    if [[ "${DOTFILES_STRICT:-}" == "1" && "$has_warnings" -eq 1 ]]; then
        echo >&2
        error "Exiting with error due to warnings (--strict mode)"
        return 1
    fi

    return 0
}

# Main installation flow
main() {
    parse_args "$@"

    echo >&2
    echo -e "${BOLD}Dotfiles Installer${NC} v${VERSION}" >&2
    echo -e "Repository: ${BLUE}github.com/${GITHUB_USER}/${GITHUB_REPO}${NC}" >&2
    echo -e "Branch: ${BLUE}${DOTFILES_BRANCH}${NC}" >&2
    echo >&2

    # Show what will happen
    info "This will:"
    echo "  - Download dotfiles to a temporary directory" >&2
    echo "  - Sync configuration files to your home directory" >&2
    [[ "${DOTFILES_NO_BREW:-}" != "1" ]] && echo "  - Install Homebrew packages (optional)" >&2
    [[ "${DOTFILES_MACOS:-}" == "1" ]] && echo "  - Apply macOS system defaults" >&2
    echo >&2

    if [[ "${DOTFILES_DRY_RUN:-}" == "1" ]]; then
        echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}" >&2
        echo >&2
    fi

    # Single confirmation to start (overwrite confirmation comes later if needed)
    if ! confirm "Continue with installation?" "y"; then
        info "Installation cancelled"
        exit 0
    fi

    echo >&2
    check_requirements

    # Offer to install Homebrew on macOS
    if [[ "$OS_TYPE" == "Darwin" ]] && ! command -v brew &>/dev/null; then
        if [[ "${DOTFILES_DRY_RUN:-}" == "1" ]]; then
            info "Dry run: skipping Homebrew installation"
        elif [[ "${DOTFILES_NO_BREW:-}" != "1" ]] && confirm_optional "Homebrew is not installed. Install it now?" "y"; then
            install_homebrew
        else
            info "Skipping Homebrew installation"
        fi
    fi

    # Download dotfiles
    local source_dir
    source_dir="$(download_dotfiles)"

    # Verify we got a valid path
    if [[ -z "$source_dir" || ! -d "$source_dir" ]]; then
        abort "Failed to locate downloaded dotfiles"
    fi

    # Check what will be overwritten (shows warning, asks confirmation if not FORCE)
    check_overwrites "$source_dir"

    # Sync files
    sync_dotfiles "$source_dir"

    # Post-sync tasks (only if not dry run)
    if [[ "${DOTFILES_DRY_RUN:-}" != "1" ]]; then
        fix_ssh_permissions
        run_brew_bundle
        apply_macos_defaults
        print_postinstall || exit 1
    else
        echo >&2
        if [[ "$OS_TYPE" == "Darwin" ]]; then
            print_brew_plan "$source_dir/Brewfile"
        else
            info "Dry run: skipping Homebrew preview on non-macOS"
            if [[ "$OS_TYPE" == "Linux" ]]; then
                info "Debian/Ubuntu hint: install packages via apt (Aptfile support not yet wired)"
            fi
        fi
        echo >&2
        info "Dry run complete. No changes were made."
        echo "Run without --dry-run to apply changes." >&2
    fi
}

# Run main function
main "$@"
