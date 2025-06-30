# dotfiles

# Usage
I recommend testing with playgrounds before using this repository.

### Install
Download this repo and make symlinks for dotfiles.
```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hskwakr/dotfiles/main/bin/install.sh)"
```

The installer clones the repository to `~/dotfiles` and links files found in
`env/common` into your home directory. Root-level dotfiles are not linked by
default.

