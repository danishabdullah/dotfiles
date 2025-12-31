# Dotfiles

Dotfiles for macOS, focused on a clean Bash-based workflow with Homebrew and sensible defaults.

## One-Line Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/danishabdullah/dotfiles/master/install.sh)"
```

This downloads and installs the dotfiles without cloning the repository. Homebrew will be installed automatically if not present.

### Install Options

Customize the installation with environment variables:

| Variable | Description |
|----------|-------------|
| `DOTFILES_DRY_RUN=1` | Preview changes without writing anything |
| `DOTFILES_FORCE=1` | Skip all confirmation prompts |
| `DOTFILES_BACKUP=<path>` | Backup overwritten files to the specified directory |
| `DOTFILES_NO_BREW=1` | Skip Homebrew package installation |
| `DOTFILES_NO_APT=1` | Skip Aptfile package installation (Debian/Ubuntu) |
| `DOTFILES_APT_DESKTOP=1` | Include Aptfile.desktop packages (Debian/Ubuntu) |
| `DOTFILES_APT_SETUP_REPOS=1` | Configure external apt repos (Caddy + Azure CLI + PostgreSQL) |
| `DOTFILES_NO_SHELL=1` | Skip changing default shell to latest bash |
| `DOTFILES_MACOS=1` | Apply macOS system defaults (requires sudo) |
| `DOTFILES_BRANCH=<name>` | Use a specific branch (default: master) |
| `DOTFILES_NO_FONTS=1` | Skip Nerd Fonts installation (Linux only) |
| `DOTFILES_DEFAULT_FONT=<name>` | Set default font (e.g., FiraCode, JetBrainsMono) |

Example with options:

```bash
DOTFILES_BACKUP=~/backup DOTFILES_MACOS=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/danishabdullah/dotfiles/master/install.sh)"
```

## Manual Install

```bash
git clone https://github.com/danishabdullah/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

### Bootstrap Options

| Flag | Description |
|------|-------------|
| `--dry-run`, `-n` | Preview without making changes |
| `--force`, `-f` | Skip confirmation prompts |
| `--backup <dir>`, `-b <dir>` | Backup overwritten files |
| `--no-brew` | Skip Homebrew bundle |
| `--no-apt` | Skip Aptfile packages (Debian/Ubuntu) |
| `--apt-desktop` | Include Aptfile.desktop packages (Debian/Ubuntu) |
| `--apt-setup-repos` | Configure external apt repos (Caddy + Azure CLI + PostgreSQL) |
| `--no-fonts` | Skip Nerd Fonts installation (Linux only) |
| `--default-font <name>` | Set default font (e.g., FiraCode, JetBrainsMono) |
| `--no-shell` | Skip changing default shell to latest bash |
| `--macos` | Apply macOS system defaults |

## What's Included

### Shell Configuration

| File | Purpose |
|------|---------|
| `.bash_profile` | Main shell config — sources all modular files |
| `.bashrc` | Minimal; sources `.bash_profile` for consistency |
| `.bash_prompt` | Solarized prompt with git status, Python/Node indicators |
| `.exports` | Environment variables (EDITOR, LANG, Python settings) |
| `.aliases` | 180+ command aliases |
| `.functions` | Utility functions (mkd, cdf, targz, fs, server, etc.) |
| `.inputrc` | Readline settings (case-insensitive completion, history search) |

### Tool Configuration

| File | Purpose |
|------|---------|
| `.gitconfig` | Git aliases, GPG signing, merge settings |
| `.gitignore` | Global ignore patterns |
| `.tmux.conf` | Tmux settings (mouse support, 250K history) |
| `.editorconfig` | Cross-editor settings (UTF-8, indentation) |
| `.curlrc` | Modern curl defaults |
| `.wgetrc` | wget options |

### Directories

| Path | Purpose |
|------|---------|
| `.config/git/` | Git commit template |
| `.ssh/` | SSH client configuration |
| `.tmuxp/` | Tmux session layouts |
| `init/` | Initialization scripts |

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | One-line installer (curl-friendly) |
| `bootstrap.sh` | Syncs dotfiles to `$HOME` using rsync |
| `brew.sh` | Installs Homebrew packages from Brewfile |
| `apt.sh` | Installs Debian/Ubuntu packages from Aptfile.core (+ Aptfile.desktop if enabled) |
| `apt-repos.sh` | Adds external apt repos (Caddy, Azure CLI, PostgreSQL; Ghostty with `--ghostty`) |
| `fonts.sh` | Installs Nerd Fonts with powerline symbols and ligatures (Linux) |
| `brew-drift-report.sh` | Audits Homebrew state vs Brewfile |
| `.macos` | Applies opinionated macOS system defaults |

### Package Lists

| File | Purpose |
|------|---------|
| `Brewfile` | Homebrew packages (macOS) |
| `Aptfile.core` | Debian/Ubuntu core packages |
| `Aptfile.desktop` | Debian/Ubuntu desktop/media packages |

## Key Features

### Python Development (uv-first)

- Auto-activates `.venv` when entering project directories
- `PIP_REQUIRE_VIRTUALENV=1` prevents accidental global installs
- Aliases: `pya` (activate), `pyd` (deactivate), `uvr` (uv run)

### Git Integration

- 30+ git aliases (l, s, d, ca, go, amend, mpr, etc.)
- GPG signing enabled by default
- URL shorthands: `gh:user/repo`, `gist:hash`
- Git status in prompt (cached for performance)

### Performance Optimizations

- Lazy-loaded bash completions
- Cached Homebrew shellenv
- Slow command timer (warns when commands exceed threshold)
- History merging across terminal sessions

### Security

- SSH: strict host key checking, no agent/X11 forwarding by default
- GPG TTY configuration for signing
- Restrictive umask (027)

### Fonts

Nerd Fonts with powerline symbols and programming ligatures are installed automatically:

| Font | Description |
|------|-------------|
| JetBrains Mono | Default. Modern, designed for developers |
| Fira Code | Popular, extensive ligatures |
| Cascadia Code | Microsoft's terminal font |
| Hack | Clean, highly readable |
| Meslo | Classic terminal font |

- **macOS**: Installed via Homebrew casks
- **Linux**: Installed via `fonts.sh` to `~/.local/share/fonts/NerdFonts`

Use `JetBrainsMono Nerd Font` (or your preferred font) in terminal and editor settings.

## Customization

### Machine-Local Settings

Create `~/.extra` for secrets and machine-specific configuration (never commit this file):

```bash
# ~/.extra
export GITHUB_TOKEN="..."
export AWS_PROFILE="personal"
```

### Custom PATH

Create `~/.path` for additional PATH entries:

```bash
# ~/.path
export PATH="$HOME/custom/bin:$PATH"
```

Both files are automatically sourced by `.bash_profile` if they exist.

## Post-Install

1. Start a new shell or run `source ~/.bash_profile`
2. Create `~/.extra` for machine-local secrets
3. Add SSH keys to `~/.ssh/` (auto-added to keychain)
4. Run `~/.macos` if you didn't use the `--macos` flag

## Updating

To pull the latest changes:

```bash
cd ~/.dotfiles  # or wherever you cloned it
git pull
./bootstrap.sh
```

Or re-run the one-liner to download fresh.

## Credits

Inspired by [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles).
