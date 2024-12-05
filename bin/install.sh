#!/bin/sh

DOT_DIR="${HOME}/dotfiles"
CACHE_DIR="${HOME}/.cache/dotfiles/default"

# At this time, cannot use ${DOT_DIR}/etc/lib/sh/has.sh
has() {
  type "$1" >/dev/null 2>&1
}

if [ ! -d "${DOT_DIR}" ]; then
  if has "git"; then
    git clone "https://github.com/hskwakr/dotfiles.git" "${DOT_DIR}"
  elif has "curl" || has "wget"; then
    TARBALL="https://github.com/hskwakr/dotfiles/archive/refs/heads/main.tar.gz"
    if has "curl"; then
      curl -L ${TARBALL} -o main.tar.gz
    else
      wget ${TARBALL}
    fi
    tar -zxvf main.tar.gz
    rm -f main.tar.gz
    mv -f dotfiles-main "${DOT_DIR}"
  else
    echo "curl or wget or git required"
    exit 1
  fi

  echo "Start installing dot files..."
  cd "${DOT_DIR}" || exit 1
  for f in .??*; do
    [ "$f" "=" ".git" ] && continue
    [ "$f" "=" ".github" ] && continue
    [ "$f" "=" ".gitignore" ] && continue
    [ "$f" "=" ".gitattributes" ] && continue

    # backup any existing dotfiles before making symlink
    if [ ! -d "${CACHE_DIR}" ]; then
      mkdir -p "${CACHE_DIR}"
    fi
    if [ -f "${HOME}/${f}" ]; then
      mv "${HOME}/${f}" "${CACHE_DIR}/${f}"
    fi

    ln -snf "${DOT_DIR}/${f}" "${HOME}/${f}"
    echo "Installed ${f}"
  done
else
  echo "dotfiles already exists"
  exit 1
fi
