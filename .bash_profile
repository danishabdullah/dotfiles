#!/usr/bin/env bash

# ----------------------
# Environment Variables
# ----------------------

# Set default encoding for Python
export PYTHONIOENCODING=utf8

# Set GPG TTY for Git commit signing
export GPG_TTY=$(tty)

# ----------------------
# Path Configuration
# ----------------------

# Function to safely append to PATH if directory exists
append_to_path() {
    if [ -d "$1" ]; then
        export PATH="$1:$PATH"
    fi
}

# Base PATH configuration
append_to_path "$HOME/bin"
append_to_path "/Applications/Postgres.app/Contents/Versions/latest/bin"
append_to_path "$HOME/.gem/bin"                                   # CocoaPods
append_to_path "$HOME/.pub-cache/bin"                            # Flutterfire
append_to_path "$HOME/code/flutter_sdk/flutter/bin"              # Flutter SDK

# ----------------------
# Shell Options
# ----------------------

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable advanced Bash 4 features
for option in autocd globstar; do
    shopt -s "$option" 2> /dev/null
done

# ----------------------
# Load External Files
# ----------------------

# Function to safely source files
safe_source() {
    if [ -r "$1" ] && [ -f "$1" ]; then
        source "$1"
    fi
}

# Load the shell dotfiles
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra,locale}; do
    safe_source "$file"
done
unset file

# ----------------------
# Homebrew Configuration
# ----------------------

# Initialize Homebrew if installed
if command -v brew &> /dev/null; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    
    # Bash completion
    if [ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]; then
        export BASH_COMPLETION_COMPAT_DIR="$(brew --prefix)/etc/bash_completion.d"
        source "$(brew --prefix)/etc/profile.d/bash_completion.sh"
    fi
elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
fi

# ----------------------
# Development Tools
# ----------------------

# Initialize rbenv if installed
if command -v rbenv &> /dev/null; then
    eval "$(rbenv init - bash)"
fi

# Initialize conda
if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
    . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
else
    append_to_path "/opt/homebrew/Caskroom/miniconda/base/bin"
fi

# Initialize Modular Magic if available
safe_source "$HOME/.modular/bin/magic"

# ----------------------
# Tab Completion
# ----------------------

# Git completion for 'g' alias
if type _git &> /dev/null; then
    complete -o default -o nospace -F _git g
fi

# SSH hostnames completion
if [ -e "$HOME/.ssh/config" ]; then
    complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh
fi

# MacOS specific completions
complete -W "NSGlobalDomain" defaults
complete -o "nospace" -W "Contacts Calendar Dock Finder Mail Safari iTunes SystemUIServer Terminal" killall

# ----------------------
# SSH Agent
# ----------------------

# Add SSH keys to agent if ssh-agent is running
if [ -n "$SSH_AGENT_PID" ]; then
    ssh-add 2>/dev/null
fi
