#!/usr/bin/env bash

# Compare the current Homebrew state with the repo’s Brewfile.
# Reports extra installs (present locally but not tracked) and missing items
# (tracked in Brewfile but not installed). Pass an alternate Brewfile path as $1.

set -euo pipefail

BFILE="${1:-Brewfile}"

if [[ ! -f "$BFILE" ]]; then
  echo "Brewfile not found at: $BFILE" >&2
  exit 1
fi

command -v brew >/dev/null 2>&1 || { echo "Homebrew not installed."; exit 1; }

sorted_unique() { LC_ALL=C sort -u; }
tracked_formulae() { awk -F'"' '/^brew "/{print $2}' "$BFILE" | sorted_unique; }
tracked_casks()    { awk -F'"' '/^cask "/{print $2}' "$BFILE" | sorted_unique; }
tracked_taps()     { awk -F'"' '/^tap "/{print $2}' "$BFILE" | sorted_unique; }

installed_formulae() { brew list --formula | sorted_unique; }
installed_casks()    { brew list --cask | sorted_unique; }
installed_taps()     { brew tap | sorted_unique; }

extras_formulae() { comm -13 <(tracked_formulae) <(installed_formulae); }
missing_formulae() { comm -23 <(tracked_formulae) <(installed_formulae); }

extras_casks() { comm -13 <(tracked_casks) <(installed_casks); }
missing_casks() { comm -23 <(tracked_casks) <(installed_casks); }

extras_taps() { comm -13 <(tracked_taps) <(installed_taps); }
missing_taps() { comm -23 <(tracked_taps) <(installed_taps); }

report_section() {
  local title="$1"; shift
  echo
  echo "## $title"
  if [[ $# -eq 0 ]]; then
    echo "(none)"
  else
    printf '%s\n' "$@"
  fi
}

echo "# Homebrew drift against ${BFILE}"

report_section "Extra formulae (installed but not tracked)" $(extras_formulae)
report_section "Missing formulae (tracked but not installed)" $(missing_formulae)
report_section "Extra casks (installed but not tracked)" $(extras_casks)
report_section "Missing casks (tracked but not installed)" $(missing_casks)
report_section "Extra taps (installed but not tracked)" $(extras_taps)
report_section "Missing taps (tracked but not installed)" $(missing_taps)
