Dotfiles for macOS, focused on a clean Bash-based workflow with Homebrew and sensible defaults.

## Quick start
- Install Homebrew first, then install the latest Bash before running anything else: `brew install bash` (or `brew update && brew install bash` if Homebrew is already present).
- Run `./bootstrap.sh` — this will run `./brew.sh` first (skip with `--no-brew`; `--dry-run` skips brew too) and then sync dotfiles. Use `--backup <dir>` to keep overwritten files, or `--dry-run` to preview. Add `--macos` to apply macOS defaults at the end (will prompt for sudo).

## Scripts
- `bootstrap.sh` – rsyncs the repo into `$HOME` with excludes. Supports `--dry-run`, `--force`, and `--backup <dir>`.
- `brew.sh` – ensures Homebrew Bash is installed, then runs `brew bundle --cleanup` with `./Brewfile`.
- `brew-drift-report.sh` – shows extra/missing Homebrew formulae/casks/taps compared to `./Brewfile`.
- `.macos` – opinionated macOS defaults; requires logout/restart for some changes.

## Notes
- The repo assumes Bash as the interactive shell; `.bash_profile` sources modular files (`.exports`, `.aliases`, `.functions`, etc.).
- Consider symlink managers (e.g., `stow`/`chezmoi`) if you prefer links over rsync; the current bootstrap copies files.
- Keep machine-local secrets in `~/.extra` (never checked in).
