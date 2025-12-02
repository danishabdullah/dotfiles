#!/usr/bin/env bash
# =============================================================================
# ~/.bash_profile — macOS (Bash) with uv-centric Python workflow
# -----------------------------------------------------------------------------
# Goals
#   • Fast, predictable login shells (no surprises for scripts / non-interactive).
#   • System (launchd) ssh-agent integration; NO custom agents or ~/.ssh/agent.
#   • uv-first Python workflow: helpers + safe `.venv` auto-activation.
#   • Homebrew env caching; lazy bash-completion; robust history merging.
#   • Clear, defensive guards to prevent startup hangs.
#
# IMPORTANT
#   • The prompt is built in ~/.bash_prompt via PROMPT_COMMAND. This file
#     *prepends* functions to PROMPT_COMMAND without clobbering the prompt.
#   • Hostname for prompts uses $PROMPT_HOST (set elsewhere as we discussed).
# =============================================================================


# =============================================================================
# 0) Base environment (idempotent)
# =============================================================================
# Prevent PATH growth if this file is re-sourced.
if [[ -z "${PATH_INITIALIZED}" ]]; then
  export PATH_INITIALIZED=1
  export PATH="$HOME/bin:$PATH"
fi

# Editors & locale
export EDITOR="nano"
export VISUAL="code"
export LANG="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"

# Interactive flag (used to gate heavy / cosmetic features)
case $- in *i*) __BASH_IS_INTERACTIVE=1 ;; *) __BASH_IS_INTERACTIVE=0 ;; esac


# =============================================================================
# 1) Modular dotfiles (optional shards; sourced only if present)
# =============================================================================
# Order matters: later files may override earlier values.
declare -a __CONFIG_FILES=(
  "$HOME/.path"          # PATH tweaks
  "$HOME/.bash_prompt"   # Fast Solarized prompt (defines PROMPT_COMMAND)
  "$HOME/.exports"
  "$HOME/.aliases"
  "$HOME/.functions"
  "$HOME/.extra"         # machine-local secrets/overrides
)
for __f in "${__CONFIG_FILES[@]}"; do
  [[ -r "$__f" && -f "$__f" ]] && source "$__f"  # shellcheck source=/dev/null
done
unset __f __CONFIG_FILES


# =============================================================================
# 2) PROMPT_COMMAND utility — safe prepend without clobbering
# =============================================================================
# Usage: __pc_prepend "func_or_cmd"
__pc_prepend() {
  if [[ -n "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="$1; $PROMPT_COMMAND"
  else
    PROMPT_COMMAND="$1"
  fi
}


# =============================================================================
# 3) Shell behaviour (history, options)
# =============================================================================
# Big history; merge across terminals; ISO timestamps.
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"
export HISTTIMEFORMAT='%F %T '
__pc_prepend 'history -a; history -c; history -r'

# Useful interactive options (no errors if unsupported)
__SHELL_OPTS=( nocaseglob histappend cdspell checkwinsize autocd globstar )
for __opt in "${__SHELL_OPTS[@]}"; do
  shopt -s "$__opt" 2>/dev/null || true
done
unset __SHELL_OPTS __opt


# =============================================================================
# 4) Bash completion (lazy)
# =============================================================================
if [[ ${__BASH_IS_INTERACTIVE} -eq 1 ]]; then
  __lazy_bash_completion() {
    local bc
    if command -v brew >/dev/null 2>&1; then
      bc="$(brew --prefix 2>/dev/null)/etc/profile.d/bash_completion.sh"
      [[ -r "$bc" ]] && source "$bc"   # shellcheck source=/dev/null
    elif [[ -r /etc/bash_completion ]]; then
      source /etc/bash_completion      # shellcheck source=/dev/null
    fi
    complete -r 2>/dev/null   # remove generic loader
  }
  complete -D -F __lazy_bash_completion

  # If git completion becomes available later, attach it to 'g' alias.
  __maybe_bind_git_completion() { type _git &>/dev/null && complete -o default -o nospace -F _git g; }
  __pc_prepend '__maybe_bind_git_completion'
fi


# =============================================================================
# 5) Homebrew (cached shellenv to avoid running `brew` every shell)
# =============================================================================
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_ENV_CACHE="$HOME/.cache/brew_shellenv.bash"
  if [[ ! -r "$BREW_ENV_CACHE" || /opt/homebrew/bin/brew -nt "$BREW_ENV_CACHE" ]]; then
    mkdir -p "$(dirname "$BREW_ENV_CACHE")"
    /opt/homebrew/bin/brew shellenv > "$BREW_ENV_CACHE"
  fi
  source "$BREW_ENV_CACHE"   # shellcheck source=/dev/null
fi


# =============================================================================
# 6) Dev tool PATHs (cheap additions only)
# =============================================================================
# Postgres.app
[[ -d "/Applications/Postgres.app" ]] && export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
# Flutter / pods / pub
if [[ -d "$HOME/code/flutter_sdk/flutter" ]]; then
  export PATH="$PATH:$HOME/code/flutter_sdk/flutter/bin"
  export PATH="$HOME/.gem/bin:$PATH"
  export PATH="$PATH:$HOME/.pub-cache/bin"
fi
# pnpm
if [[ -d "$HOME/Library/pnpm" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  export PATH="$PNPM_HOME:$PATH"
fi
# Rust (cargo)
if [[ -d "$HOME/.cargo/bin" ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
# Java (OpenJDK)
if [[ -d "/opt/homebrew/opt/openjdk" ]]; then
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  export JAVA_HOME="/opt/homebrew/opt/openjdk"
fi


# =============================================================================
# 7) uv-centric Python helpers + SAFE `.venv` auto-activation
# =============================================================================
# Lightweight helpers (present whether or not uv is installed)
alias pya='[ -f .venv/bin/activate ] && source .venv/bin/activate || echo ".venv not found"'
alias pyd='type deactivate >/dev/null 2>&1 && deactivate || true'

# If uv exists, provide nicer shortcuts.
if command -v uv >/dev/null 2>&1; then
  alias uvr='uv run'
  alias uva='uv add'
  alias uvu='uv pip upgrade'
  alias uvx='uvx'
  uvp() { uv venv "$@"; }
fi

# --- AUTO-ACTIVATION DETAILS --------------------------------------------------
# Symptoms you reported (hang) were caused by a fragile parent-directory walk.
# This implementation is defensive and *terminates at the root reliably*.
#
# • Looks for the nearest "<project-root>/.venv/bin/activate" from $PWD upwards.
# • Activates only when not already active; deactivates when leaving the tree.
# • Only deactivates envs that *it* activated, so manual activations are respected.
# • Toggle with:  export UV_AUTO_ACTIVATE=0   (default: 1)
UV_AUTO_ACTIVATE=${UV_AUTO_ACTIVATE:-1}
__UV_ACTIVATED_FROM=""

__uv_find_project_venv() {
  # Echo absolute path to ".venv" if found, else echo nothing.
  local dir="$PWD" parent
  while :; do
    if [[ -f "$dir/.venv/bin/activate" ]]; then
      printf '%s\n' "$dir/.venv"
      return 0
    fi
    # Stop at root
    [[ "$dir" == "/" ]] && return 1
    # Robust parent resolution: parameter expansion with root fallback
    parent="${dir%/*}"
    [[ -z "$parent" || "$parent" == "$dir" ]] && parent="/"
    dir="$parent"
  done
}

__uv_auto_activate() {
  [[ ${__BASH_IS_INTERACTIVE} -eq 1 ]] || return
  [[ "$UV_AUTO_ACTIVATE" == "1" ]] || return

  local found; found="$(__uv_find_project_venv)" || true

  if [[ -n "$found" ]]; then
    # Activate if not already in this env
    if [[ "$VIRTUAL_ENV" != "$found" ]]; then
      # Only deactivate if we previously auto-activated a different env
      if [[ -n "$__UV_ACTIVATED_FROM" && -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" != "$found" ]]; then
        type deactivate >/dev/null 2>&1 && deactivate || true
      fi
      # shellcheck source=/dev/null
      source "$found/bin/activate" 2>/dev/null && __UV_ACTIVATED_FROM="$found"
    fi
  else
    # No env in tree → deactivate only if we were the ones who activated it
    if [[ -n "$__UV_ACTIVATED_FROM" && -n "$VIRTUAL_ENV" ]]; then
      type deactivate >/dev/null 2>&1 && deactivate || true
      __UV_ACTIVATED_FROM=""
    fi
  fi
}
# Run before prompt builder (from ~/.bash_prompt)
__pc_prepend '__uv_auto_activate'


# =============================================================================
# 8) Security & authentication (GPG + launchd ssh-agent)
# =============================================================================
export GPG_TTY="$(tty)"

# Attach to system ssh-agent socket; never spawn a new agent.
if [[ -z "${SSH_AUTH_SOCK}" || ! -S "${SSH_AUTH_SOCK}" ]]; then
  __found_sock=""
  for p in /private/tmp/com.apple.launchd.*/*; do
    [[ -S "$p" ]] && __found_sock="$p" && break
  done
  if [[ -z "$__found_sock" ]]; then
    __tmp="${TMPDIR%/}"
    for p in "${__tmp}"/*/agent.* "${TMPDIR}"ssh-*/agent.*; do
      [[ -S "$p" ]] && __found_sock="$p" && break
    done
    unset __tmp
  fi
  [[ -n "$__found_sock" ]] && export SSH_AUTH_SOCK="$__found_sock"
  unset __found_sock p
fi

# Optionally prime a default key (interactive only; silent if unavailable)
if [[ ${__BASH_IS_INTERACTIVE} -eq 1 ]]; then
  __DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519"
  if [[ -r "$__DEFAULT_SSH_KEY" ]] && ! ssh-add -l >/dev/null 2>&1; then
    ssh-add --apple-use-keychain "$__DEFAULT_SSH_KEY" >/dev/null 2>&1 || true
  fi
  unset __DEFAULT_SSH_KEY
fi


# =============================================================================
# 9) Additional tools (safe source or alias)
# =============================================================================
# Only source if it’s a shell script (binary will just be exposed via alias).
if [[ -r "$HOME/.modular/bin/magic" ]] && head -c 2 "$HOME/.modular/bin/magic" | grep -q '^#!'; then
  source "$HOME/.modular/bin/magic"   # shellcheck source=/dev/null
elif [[ -x "$HOME/.modular/bin/magic" ]]; then
  alias magic="$HOME/.modular/bin/magic"
fi


# =============================================================================
# 10) Pager & terminal niceties (safe everywhere)
# =============================================================================
export LESS='-FRSX'
export LESSHISTFILE=-
export LESS_TERMCAP_mb=$'\e[1m'
export LESS_TERMCAP_md=$'\e[1m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[7m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4m'
export LESS_TERMCAP_ue=$'\e[0m'


# =============================================================================
# 11) Sensible limits & umask (best-effort)
# =============================================================================
__curr_ulimit="$(ulimit -n 2>/dev/null || echo 256)"
if [[ "$__curr_ulimit" -lt 65536 ]]; then ulimit -n 65536 2>/dev/null || true; fi
unset __curr_ulimit
umask 027


# =============================================================================
# 12) Optional startup profiling
# =============================================================================
if [[ "${PROFILE_STARTUP}" == "true" ]]; then
  PS4='+ $(date "+%s.%N")\011 '
  exec 3>&2 2>/tmp/bashstart.$$.log
  set -x
fi


# =============================================================================
# 13) Local overlay (last — can override anything above)
# =============================================================================
[[ -r "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"   # shellcheck source=/dev/null
