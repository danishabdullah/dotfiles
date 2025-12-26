#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__DOTFILES_OS_LOADED:-}" ]]; then
	return 0
fi
__DOTFILES_OS_LOADED=1

__DOTFILES_OS_NAME="$(uname -s 2>/dev/null || echo unknown)"
__DOTFILES_IS_MACOS=0
__DOTFILES_IS_LINUX=0
__DOTFILES_IS_DEBIAN=0
__DOTFILES_IS_WSL=0
__DOTFILES_OS_ID=""
__DOTFILES_OS_ID_LIKE=""
__DOTFILES_OS_VERSION=""

case "$__DOTFILES_OS_NAME" in
	Darwin) __DOTFILES_IS_MACOS=1 ;;
	Linux) __DOTFILES_IS_LINUX=1 ;;
esac

if [[ "$__DOTFILES_IS_LINUX" -eq 1 ]]; then
	if grep -qi microsoft /proc/version 2>/dev/null; then
		__DOTFILES_IS_WSL=1
	fi
	if [[ -r /etc/os-release ]]; then
		__DOTFILES_OS_ID="$(awk -F= '$1=="ID"{print $2}' /etc/os-release | tr -d '"')"
		__DOTFILES_OS_ID_LIKE="$(awk -F= '$1=="ID_LIKE"{print $2}' /etc/os-release | tr -d '"')"
		__DOTFILES_OS_VERSION="$(awk -F= '$1=="VERSION_ID"{print $2}' /etc/os-release | tr -d '"')"
		if [[ "$__DOTFILES_OS_ID" == "debian" || "$__DOTFILES_OS_ID_LIKE" == *debian* ]]; then
			__DOTFILES_IS_DEBIAN=1
		fi
	fi
fi

if [[ "$__DOTFILES_IS_MACOS" -eq 1 ]]; then
	DOTFILES_OS="macos"
elif [[ "$__DOTFILES_IS_WSL" -eq 1 ]]; then
	DOTFILES_OS="wsl"
elif [[ "$__DOTFILES_IS_DEBIAN" -eq 1 ]]; then
	DOTFILES_OS="debian"
elif [[ "$__DOTFILES_IS_LINUX" -eq 1 ]]; then
	DOTFILES_OS="linux"
else
	DOTFILES_OS="unknown"
fi

dotfiles_is_macos() { [[ "$__DOTFILES_IS_MACOS" -eq 1 ]]; }
dotfiles_is_linux() { [[ "$__DOTFILES_IS_LINUX" -eq 1 ]]; }
dotfiles_is_debian() { [[ "$__DOTFILES_IS_DEBIAN" -eq 1 ]]; }
dotfiles_is_wsl() { [[ "$__DOTFILES_IS_WSL" -eq 1 ]]; }
