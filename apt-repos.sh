#!/usr/bin/env bash
# Set up external apt repositories for Debian/Ubuntu packages.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./apt-repos.sh [--all] [--caddy] [--azure-cli] [--postgres] [--ghostty]

Options:
  --all        Set up core repos: Caddy, Azure CLI, PostgreSQL (default)
  --caddy      Add Caddy repository
  --azure-cli  Add Azure CLI repository
  --postgres   Add PostgreSQL (PGDG) repository
  --ghostty    Add Ghostty terminal repository (desktop only, not in --all)
  -h, --help   Show this help
EOF
}

WANT_CADDY=0
WANT_AZURE=0
WANT_PG=0
WANT_GHOSTTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) WANT_CADDY=1; WANT_AZURE=1; WANT_PG=1 ;;  # Ghostty excluded (desktop-only)
    --caddy) WANT_CADDY=1 ;;
    --azure-cli) WANT_AZURE=1 ;;
    --postgres) WANT_PG=1 ;;
    --ghostty) WANT_GHOSTTY=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

# Default to core repos only (Ghostty is desktop-only, must be explicitly requested)
if [[ $WANT_CADDY -eq 0 && $WANT_AZURE -eq 0 && $WANT_PG -eq 0 && $WANT_GHOSTTY -eq 0 ]]; then
  WANT_CADDY=1
  WANT_AZURE=1
  WANT_PG=1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Unsupported OS: /etc/os-release not found" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found; this script is for Debian/Ubuntu." >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

# Install prerequisites if missing
need_pkgs=()
for p in ca-certificates curl gnupg; do
  dpkg -s "$p" >/dev/null 2>&1 || need_pkgs+=("$p")
done
if [[ ${#need_pkgs[@]} -gt 0 ]]; then
  $SUDO apt-get update || true
  $SUDO apt-get install -y "${need_pkgs[@]}"
fi

. /etc/os-release
CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
if [[ -z "$CODENAME" ]] && command -v lsb_release >/dev/null 2>&1; then
  CODENAME="$(lsb_release -cs 2>/dev/null || true)"
fi
if [[ -z "$CODENAME" ]]; then
  echo "Unable to determine OS codename." >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

setup_caddy() {
  local keyring="/usr/share/keyrings/caddy-stable-archive-keyring.gpg"
  local list="/etc/apt/sources.list.d/caddy-stable.list"
  if [[ -f "$list" ]] && grep -q "caddy/stable" "$list"; then
    echo "Caddy repo already configured"
    return 0
  fi
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | $SUDO gpg --dearmor -o "$keyring"
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | $SUDO tee "$list" >/dev/null
  echo "Caddy repo configured"
}

setup_azure_cli() {
  local keyring="/usr/share/keyrings/microsoft-archive-keyring.gpg"
  local list="/etc/apt/sources.list.d/azure-cli.list"
  if [[ -f "$list" ]] && grep -q "azure-cli" "$list"; then
    echo "Azure CLI repo already configured"
    return 0
  fi
  curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" | $SUDO gpg --dearmor -o "$keyring"
  echo "deb [arch=${ARCH} signed-by=${keyring}] https://packages.microsoft.com/repos/azure-cli/ ${CODENAME} main" | $SUDO tee "$list" >/dev/null
  echo "Azure CLI repo configured"
}

setup_postgres() {
  local keyring="/usr/share/keyrings/postgresql.gpg"
  local list="/etc/apt/sources.list.d/pgdg.list"
  if [[ -f "$list" ]] && grep -q "apt.postgresql.org" "$list"; then
    echo "PostgreSQL repo already configured"
    return 0
  fi
  curl -fsSL "https://www.postgresql.org/media/keys/ACCC4CF8.asc" | $SUDO gpg --dearmor -o "$keyring"
  echo "deb [signed-by=${keyring}] https://apt.postgresql.org/pub/repos/apt/ ${CODENAME}-pgdg main" | $SUDO tee "$list" >/dev/null
  echo "PostgreSQL repo configured"
}

setup_ghostty() {
  local keyring="/usr/share/keyrings/ghostty.gpg"
  local list="/etc/apt/sources.list.d/ghostty.list"
  if [[ -f "$list" ]] && grep -q "debian.griffo.io" "$list"; then
    echo "Ghostty repo already configured"
    return 0
  fi
  curl -fsSL "https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc" | $SUDO gpg --dearmor -o "$keyring"
  echo "deb [arch=${ARCH} signed-by=${keyring}] https://debian.griffo.io/apt ${CODENAME} main" | $SUDO tee "$list" >/dev/null
  echo "Ghostty repo configured"
}

if [[ $WANT_CADDY -eq 1 ]]; then
  setup_caddy
fi

if [[ $WANT_AZURE -eq 1 ]]; then
  setup_azure_cli
fi

if [[ $WANT_PG -eq 1 ]]; then
  setup_postgres
fi

if [[ $WANT_GHOSTTY -eq 1 ]]; then
  setup_ghostty
fi

echo "Done. Run apt-get update to refresh package lists."
