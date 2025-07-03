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

## Testing with Docker
The repository provides basic [BATS](https://github.com/bats-core/bats-core) tests.
Run them inside a container with the helper script:

```sh
cd test
./run_tests.sh sample.bats
```

This script builds a Docker image based on `bats/bats:latest` and executes the given
`*.bats` files. The image copies the repository at build time so no volume mount is needed.
See [doc/projects/testing.md](doc/projects/testing.md) for details.
For a TDD-style workflow that writes failing tests first, see
[doc/projects/tdd.md](doc/projects/tdd.md).

### Continuous Integration
BATS tests run automatically on each pull request via GitHub Actions. The workflow is defined in `.github/workflows/test.yml`.
