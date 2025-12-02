#!/usr/bin/env bash

# Single-source Homebrew setup for this repo.
# Usage: ./brew.sh           # apply Brewfile in the repo
#        ./brew.sh --force   # skip interactive prompts
set -euo pipefail

BREWFILE="${BREWFILE:-$(dirname "$0")/Brewfile}"

if [[ ! -f "$BREWFILE" ]]; then
  echo "Brewfile not found at $BREWFILE" >&2
  exit 1
fi

brew update

# Install latest bash first so subsequent scripts run under a modern shell.
if ! brew list --formula bash >/dev/null 2>&1; then
  brew install bash
fi

brew bundle install --cleanup --file="$BREWFILE" "$@"
brew autoremove
brew cleanup
