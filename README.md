# dotfiles

Configuration files for various development environments.
See [doc/index.md](doc/index.md) for detailed documentation and policies.

## Prerequisites
The installation scripts expect the following commands to be available:

- `bash`, `curl`, and `git`
- standard utilities such as `cp` and `ln`
Ensure the scripts in `bin/` are executable before running them.

## Quick Install
Download this repo and create symlinks for the dotfiles:
```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hskwakr/dotfiles/main/bin/install.sh)"
```
