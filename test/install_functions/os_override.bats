#!/usr/bin/env bats

# Tests for the common/OS-specific override (last-wins) behavior.
# When both env/common/ and env/<OS>/ contain the same file,
# the OS-specific version must be the final symlink target.

setup() {
  HOME_DIR="$BATS_TMPDIR/home"
  DOTFILES_DIR="$BATS_TMPDIR/repo"
  mkdir -p "$HOME_DIR" "$DOTFILES_DIR"
  export HOME="$HOME_DIR"

  source "$BATS_TEST_DIRNAME/../../bin/install.sh"

  DOTFILES_DIR="$BATS_TMPDIR/repo"
  BACKUP_DIR="$DOTFILES_DIR/backups"
  ORIGINAL_BACKUP_DIR="$BACKUP_DIR/original"
  LOG_DIR="$DOTFILES_DIR/logs"
  LOG_FILE="$LOG_DIR/install.log"
  LOG_MAX_SIZE=1024
  LOG_BACKUP_COUNT=3
  BACKUP_MAX_COUNT=5
  ignore_list=()

  log() { :; }
}

teardown() {
  rm -rf "$HOME_DIR" "$DOTFILES_DIR"
}

@test "OS-specific file overrides common file with same name" {
  mkdir -p "$DOTFILES_DIR/env/common"
  mkdir -p "$DOTFILES_DIR/env/macOS"
  echo "common content" > "$DOTFILES_DIR/env/common/.tmux.conf"
  echo "macOS content" > "$DOTFILES_DIR/env/macOS/.tmux.conf"

  # Simulate install order: common first, then OS
  install_env_common
  [ -L "$HOME/.tmux.conf" ]
  [ "$(readlink "$HOME/.tmux.conf")" = "$DOTFILES_DIR/env/common/.tmux.conf" ]

  install_env_os "macOS"
  [ -L "$HOME/.tmux.conf" ]
  [ "$(readlink "$HOME/.tmux.conf")" = "$DOTFILES_DIR/env/macOS/.tmux.conf" ]
}

@test "common-only files remain after OS override" {
  mkdir -p "$DOTFILES_DIR/env/common"
  mkdir -p "$DOTFILES_DIR/env/macOS"
  echo "common gitconfig" > "$DOTFILES_DIR/env/common/.gitconfig"
  echo "common tmux" > "$DOTFILES_DIR/env/common/.tmux.conf"
  echo "macOS tmux" > "$DOTFILES_DIR/env/macOS/.tmux.conf"

  install_env_common
  install_env_os "macOS"

  # .gitconfig is common-only and should still point to common
  [ -L "$HOME/.gitconfig" ]
  [ "$(readlink "$HOME/.gitconfig")" = "$DOTFILES_DIR/env/common/.gitconfig" ]

  # .tmux.conf should point to OS-specific version
  [ -L "$HOME/.tmux.conf" ]
  [ "$(readlink "$HOME/.tmux.conf")" = "$DOTFILES_DIR/env/macOS/.tmux.conf" ]
}

@test "OS override preserves original backup of real file" {
  mkdir -p "$DOTFILES_DIR/env/common"
  mkdir -p "$DOTFILES_DIR/env/macOS"
  mkdir -p "$BACKUP_DIR" "$ORIGINAL_BACKUP_DIR"
  echo "common tmux" > "$DOTFILES_DIR/env/common/.tmux.conf"
  echo "macOS tmux" > "$DOTFILES_DIR/env/macOS/.tmux.conf"

  # Place a real file in HOME before install
  echo "user original" > "$HOME/.tmux.conf"

  install_env_common
  install_env_os "macOS"

  # Final link points to OS-specific
  [ -L "$HOME/.tmux.conf" ]
  [ "$(readlink "$HOME/.tmux.conf")" = "$DOTFILES_DIR/env/macOS/.tmux.conf" ]

  # Original backup was created during the common step and preserved
  [ -f "$ORIGINAL_BACKUP_DIR/.tmux.conf" ]
  grep -q "user original" "$ORIGINAL_BACKUP_DIR/.tmux.conf"
}

@test "OS override works with nested directories" {
  mkdir -p "$DOTFILES_DIR/env/common/.config/sub"
  mkdir -p "$DOTFILES_DIR/env/macOS/.config/sub"
  echo "common file" > "$DOTFILES_DIR/env/common/.config/sub/settings"
  echo "macOS file" > "$DOTFILES_DIR/env/macOS/.config/sub/settings"

  install_env_common
  install_env_os "macOS"

  [ -L "$HOME/.config/sub/settings" ]
  [ "$(readlink "$HOME/.config/sub/settings")" = "$DOTFILES_DIR/env/macOS/.config/sub/settings" ]
}

@test "override log message is emitted for common-to-OS replacement" {
  mkdir -p "$DOTFILES_DIR/env/common"
  mkdir -p "$DOTFILES_DIR/env/macOS"
  echo "common" > "$DOTFILES_DIR/env/common/.tmux.conf"
  echo "macOS" > "$DOTFILES_DIR/env/macOS/.tmux.conf"

  # Use a log function that captures output
  log() { echo "$@"; }

  install_env_common
  local output
  output=$(install_env_os "macOS" 2>&1)

  [[ "$output" == *"Overriding common config with OS-specific version"* ]]
}

@test "install_env_common runs before install_env_os in main" {
  # Verify the source code order to guard against accidental reordering
  local install_script="$BATS_TEST_DIRNAME/../../bin/install.sh"
  local common_line os_line

  common_line=$(grep -n "install_env_common" "$install_script" | grep -v "#" | grep -v "()" | tail -1 | cut -d: -f1)
  os_line=$(grep -n "install_env_os" "$install_script" | grep -v "#" | grep -v "()" | tail -1 | cut -d: -f1)

  [ -n "$common_line" ]
  [ -n "$os_line" ]
  [ "$common_line" -lt "$os_line" ]
}
