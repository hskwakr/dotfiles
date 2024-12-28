#!/bin/sh
# Remove dotfiles and this repository

DOT_DIR="${HOME}/dotfiles"
CACHE_DIR="${HOME}/.cache/dotfiles"
DEFAULT_DIR="${CACHE_DIR}/default"

if [ -d "${DOT_DIR}" ]; then
  cd "${DOT_DIR}" || exit 1
  echo "Remove linked dot files from dotfiles repository..."
  for f in .??*; do
    [ "$f" "=" ".git" ] && continue
    [ "$f" "=" ".github" ] && continue
    [ "$f" "=" ".gitignore" ] && continue
    [ "$f" "=" ".gitattributes" ] && continue

    sudo rm -rf "${HOME:?}/${f}"
    echo "... Removed ${f}"

    if [ -d "${DEFAULT_DIR}" ]; then
      if [ -f "${DEFAULT_DIR}/${f}" ]; then
        mv "${DEFAULT_DIR}/${f}" "${HOME}/${f}"
      fi
    fi
  done

  # Remove cache dir for dotfiles
  sudo rm -rf "${CACHE_DIR:?}"
  echo "... Removed ${CACHE_DIR}"
  # Remove dotfiles dir
  sudo rm -rf "${DOT_DIR:?}"
  echo "... Removed ${DOT_DIR}"
else
  echo "dotfiles does not exists"
  exit 1
fi
