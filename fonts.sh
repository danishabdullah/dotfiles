#!/usr/bin/env bash
# Install Nerd Fonts (powerline + ligatures) on Linux
# Usage: ./fonts.sh [--font NAME] [--list] [--help]
#
# Fonts are downloaded from https://github.com/ryanoasis/nerd-fonts
set -euo pipefail

NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-v3.3.0}"
FONT_DIR="${HOME}/.local/share/fonts/NerdFonts"

# Available fonts (subset of most popular programming fonts)
AVAILABLE_FONTS=(
  "JetBrainsMono"
  "FiraCode"
  "CascadiaCode"
  "Hack"
  "Meslo"
)

# Default fonts to install (all of them)
DEFAULT_FONTS=("${AVAILABLE_FONTS[@]}")

# Default font for terminal/editor configs
DEFAULT_FONT_NAME="${DOTFILES_DEFAULT_FONT:-JetBrainsMono}"

usage() {
  cat <<'EOF'
Usage: ./fonts.sh [OPTIONS]

Install Nerd Fonts with powerline symbols and ligatures support.

Options:
  --all              Install all available fonts (default)
  --font NAME        Install only the specified font (can be repeated)
  --default NAME     Set default font for configs (default: JetBrainsMono)
  --list             List available fonts
  --version VER      Nerd Fonts release version (default: v3.3.0)
  -h, --help         Show this help

Environment Variables:
  DOTFILES_DEFAULT_FONT   Default font name (e.g., FiraCode)
  NERD_FONTS_VERSION      Release version to download

Examples:
  ./fonts.sh                          # Install all fonts
  ./fonts.sh --font JetBrainsMono     # Install only JetBrains Mono
  ./fonts.sh --font FiraCode --font Hack  # Install multiple fonts
  DOTFILES_DEFAULT_FONT=FiraCode ./fonts.sh  # Set FiraCode as default
EOF
}

list_fonts() {
  echo "Available Nerd Fonts:"
  for font in "${AVAILABLE_FONTS[@]}"; do
    if [[ "$font" == "$DEFAULT_FONT_NAME" ]]; then
      echo "  - $font (default)"
    else
      echo "  - $font"
    fi
  done
}

# Check if a font name is valid
is_valid_font() {
  local name="$1"
  for font in "${AVAILABLE_FONTS[@]}"; do
    [[ "$font" == "$name" ]] && return 0
  done
  return 1
}

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux. On macOS, use: brew install --cask font-*-nerd-font" >&2
  exit 0
fi

# Parse arguments
SELECTED_FONTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      SELECTED_FONTS=("${AVAILABLE_FONTS[@]}")
      ;;
    --font)
      [[ -z "${2:-}" ]] && { echo "Error: --font requires a name" >&2; exit 1; }
      SELECTED_FONTS+=("$2")
      shift
      ;;
    --default)
      [[ -z "${2:-}" ]] && { echo "Error: --default requires a name" >&2; exit 1; }
      if ! is_valid_font "$2"; then
        echo "Warning: '$2' is not a known font. Available: ${AVAILABLE_FONTS[*]}" >&2
      fi
      DEFAULT_FONT_NAME="$2"
      shift
      ;;
    --version)
      [[ -z "${2:-}" ]] && { echo "Error: --version requires a version" >&2; exit 1; }
      NERD_FONTS_VERSION="$2"
      shift
      ;;
    --list)
      list_fonts
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

# Default to all fonts if none specified
if [[ ${#SELECTED_FONTS[@]} -eq 0 ]]; then
  SELECTED_FONTS=("${DEFAULT_FONTS[@]}")
fi

# Check for required tools
for cmd in curl unzip; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed" >&2
    exit 1
  fi
done

# Create secure temp directory for downloads
TMPDIR_FONTS="$(mktemp -d)" || { echo "Error: Failed to create temp directory" >&2; exit 1; }
trap 'rm -rf "$TMPDIR_FONTS"' EXIT

# Create font directory
mkdir -p "$FONT_DIR"

echo "Installing Nerd Fonts ${NERD_FONTS_VERSION}..."
echo "Font directory: $FONT_DIR"
echo ""

# Download and install each font
for font in "${SELECTED_FONTS[@]}"; do
  # Validate font name
  valid=0
  for available in "${AVAILABLE_FONTS[@]}"; do
    if [[ "$font" == "$available" ]]; then
      valid=1
      break
    fi
  done
  if [[ $valid -eq 0 ]]; then
    echo "Warning: Unknown font '$font', skipping" >&2
    continue
  fi

  zip_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"
  zip_file="${TMPDIR_FONTS}/${font}.zip"

  echo "Downloading ${font}..."
  if curl -fsSL -o "$zip_file" "$zip_url"; then
    echo "Extracting ${font}..."
    unzip -o -q "$zip_file" -d "$FONT_DIR" -x "*.txt" -x "*.md" -x "LICENSE" 2>/dev/null || true
    rm -f "$zip_file"
    echo "  Installed: ${font}"
  else
    echo "  Failed to download ${font}" >&2
  fi
done

# Refresh font cache
echo ""
echo "Refreshing font cache..."
if command -v fc-cache &>/dev/null; then
  fc-cache -f "$FONT_DIR"
  echo "Font cache updated"
else
  echo "Warning: fc-cache not found, you may need to refresh fonts manually" >&2
fi

echo ""
echo "Done! Installed fonts:"
if [[ -d "$FONT_DIR" ]] && ls -1 "$FONT_DIR"/*.ttf "$FONT_DIR"/*.otf &>/dev/null; then
  find "$FONT_DIR" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -printf '%f\n' 2>/dev/null | sed 's/\.[^.]*$//' | sort -u | head -20
  font_count=$(find "$FONT_DIR" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) 2>/dev/null | wc -l)
  echo "Total: ${font_count} font files"
else
  echo "  (no fonts found)"
fi

# Configure default font in terminal and editor configs
FONT_FULL_NAME="${DEFAULT_FONT_NAME} Nerd Font"
echo ""
echo "Configuring default font: ${FONT_FULL_NAME}"

# Update Ghostty config
GHOSTTY_CONFIG="${HOME}/.config/ghostty/config"
if [[ -f "$GHOSTTY_CONFIG" ]]; then
  if grep -q "^font-family" "$GHOSTTY_CONFIG"; then
    sed -i "s/^font-family.*/font-family = \"${FONT_FULL_NAME}\"/" "$GHOSTTY_CONFIG"
    echo "  Updated Ghostty config"
  else
    echo "font-family = \"${FONT_FULL_NAME}\"" >> "$GHOSTTY_CONFIG"
    echo "  Added font to Ghostty config"
  fi
fi

# Update VSCode settings
VSCODE_SETTINGS="${HOME}/.config/Code/User/settings.json"
if [[ -f "$VSCODE_SETTINGS" ]]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json
import sys
try:
    with open('$VSCODE_SETTINGS', 'r') as f:
        settings = json.load(f)
    settings['editor.fontFamily'] = \"'${FONT_FULL_NAME}', 'Droid Sans Mono', 'monospace'\"
    settings['terminal.integrated.fontFamily'] = \"'${FONT_FULL_NAME}'\"
    with open('$VSCODE_SETTINGS', 'w') as f:
        json.dump(settings, f, indent=4)
    print('  Updated VSCode settings')
except Exception as e:
    print(f'  Warning: Could not update VSCode settings: {e}', file=sys.stderr)
"
  else
    echo "  Warning: python3 not found, skipping VSCode config update" >&2
  fi
fi

echo ""
echo "Default font: ${FONT_FULL_NAME}"
echo "Configured in: Ghostty, VSCode"
