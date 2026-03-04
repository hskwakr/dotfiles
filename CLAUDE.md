# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal dotfiles manager supporting multiple OS environments (macOS, Fedora, WSL, WSL-Ubuntu, etc). Scripts install configuration files via symlinks with automatic backup and restoration.

All documentation in `doc/` and AGENTS.md is written in Japanese.

## Commands

### Run all tests (Docker, recommended)
```sh
cd test && ./run_tests.sh
```

### Run all tests (local BATS)
```sh
bats --formatter pretty --recursive test
```

### Run a single test file
```sh
bats test/install_functions/backup_and_link.bats
```

### CI
GitHub Actions runs BATS on pull requests (`.github/workflows/test.yml`).

## Architecture

### Installation flow (`bin/install.sh`)
1. Detect OS via `detect_os()` (uname + /etc/os-release)
2. Clone/update repo via `prepare_repo()`
3. Link common dotfiles from `env/common/` to `$HOME`
4. Link OS-specific dotfiles from `env/<OS>/` with fallback chain (e.g. wsl-ubuntu → wsl)
5. Optionally change default shell (`-s` flag)

### Key directories
- `bin/` — Install (`install.sh`), cleanup (`clean.sh`), list (`list.sh`) scripts
- `bin/lib/helpers.sh` — Shared functions (`log()`, `is_ignored()`)
- `env/common/` — Dotfiles for all environments
- `env/<OS>/` — OS-specific dotfiles (fedora, macOS, wsl, wsl-ubuntu, etc)
- `test/` — BATS test suite; subdirectories mirror function names

### Backup system
- `backups/original/` — One-time backup of original files before first symlink
- `backups/*.bak` — Timestamped backups, auto-rotated
- `logs/install.log` — Managed with rotation (1MB max, 5 rotated files)

## Shell Script Conventions

- Always start scripts with `set -euo pipefail`
- Check external commands exist with `command -v <cmd>` before use
- Quote all variable expansions: `"${var}"`
- Modularize logic into small, testable functions
- Add a comment above each function describing its purpose; keep comments in sync with code
- When modifying scripts, create or update corresponding BATS tests
- Always use `--formatter pretty` when running BATS
