#!/bin/sh

# Show list of dotfiles
DOT_DIR="${HOME}/dotfiles"

if [ -d "${DOT_DIR}" ]; then
  cd "${DOT_DIR}" || exit 1
  echo "Show list of available dotfiles in dotfiles repository..."
  for f in .??*; do
    [ "$f" = ".git" ] && continue
    [ "$f" = ".github" ] && continue
    [ "$f" = ".gitignore" ] && continue
    [ "$f" = ".gitattributes" ] && continue

    echo "${HOME}/$f"
  done
else
  echo "dotfiles does not exist"
  exit 1
fi
