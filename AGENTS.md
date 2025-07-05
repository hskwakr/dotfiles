# AGENTS

このリポジトリのスクリプト方針は [doc/agents/overview.md](doc/agents/overview.md) にまとめています。
詳細なポリシーについては [doc/index.md](doc/index.md) を参照してください。
dotfiles プロジェクト全体の概要は [doc/projects/dotfiles.md](doc/projects/dotfiles.md) にまとめています。
シェルスクリプトの具体的な推奨設定は [doc/projects/guideline.md](doc/projects/guideline.md) で解説しています。
AGENTS.md と `doc/` 以下のドキュメントはすべて日本語で記述されています。

## フォルダ構成

- `bin/` - インストールやクリーンアップに使用するスクリプトを配置します。
  - `install.sh` - dotfiles をインストールするメインスクリプト
  - `clean.sh`   - バックアップやログを整理するスクリプト
  - `list.sh`    - dotfiles の一覧を表示するスクリプト
- `env/` - 環境別の設定ファイルを格納します。
  - `common/` - すべての環境で共通して利用する設定
  - `fedora/` - Fedora Linux 用の設定
  - `macOS/`  - macOS 用の設定
  - `wsl/`    - Windows Subsystem for Linux 用の設定
- `README.md` - リポジトリの概要や使用方法を記載したファイル
- `LICENSE` - ライセンス情報

## テストの実行について

詳細な手順は [doc/projects/testing.md](doc/projects/testing.md) を参照してください。
基本的には Docker を利用した `test/run_tests.sh` を実行しますが、Docker が利用で
きない環境では BATS を直接インストールしてテストできます。


BATS をローカルにインストールする場合は、[公式サイト](https://github.com/bats-core/bats-core) の手順に従ってください。
```sh
bats --recursive test
```

特定のテストだけを実行したい場合はパスを指定してください。
