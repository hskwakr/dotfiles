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

## Testing
The repository provides basic [BATS](https://github.com/bats-core/bats-core) tests.
You can run them locally using the Docker helper script or by installing BATS directly.

```sh
# Using Docker
cd test
./run_tests.sh

# Or with a local BATS installation
bats --formatter pretty --recursive test
```

See [doc/projects/testing.md](doc/projects/testing.md) for details on both approaches.
For a TDD-style workflow that writes failing tests first, see
[doc/projects/tdd.md](doc/projects/tdd.md).

### Continuous Integration
BATS tests run automatically on each pull request via GitHub Actions. The workflow is defined in `.github/workflows/test.yml`.
