# テスト実行ガイド

このドキュメントでは、Docker またはローカルにインストールした BATS を利用してテストを実行する方法を説明します。

## 前提条件
- Docker が利用できる、もしくは BATS がインストールされていること

## 実行方法
### Docker を使う場合
1. `test/` ディレクトリで Docker イメージをビルドし、BATS を実行します。
   ```sh
   cd test
   ./run_tests.sh
   ```
このスクリプトは `--formatter pretty` を BATS に渡し、`TERM=xterm` を設定した状態で
実行するため、非対話環境でも色付き出力が得られます。テストファイルごとの見出
しを表示します。引数を指定すると個別のテストを実行できます。
テストファイルは `test/` 以下のディレクトリ構造で対象スクリプトや関数を示すため、
出力された見出しからどの部分を検証しているか把握できます。
例えば `bin/install.sh` のテストは `test/bin/install/` に置き、
ファイル名で具体的な関数名を表します。

Docker イメージは `bats/bats:latest` をベースにしており、ビルド時にリポジトリ全体を `/work` にコピーします。そのため、実行時にボリュームマウントを指定する必要はありません。

### ローカルに BATS をインストールする場合
1. BATS のインストール方法については [公式サイト](https://github.com/bats-core/bats-core) を参照してください。
2. その後、リポジトリ直下で次のように実行します。
   ```sh
   bats --formatter pretty --recursive test
   ```
   特定のテストだけを実行したい場合はパスを指定します。

## CI での自動実行

このリポジトリでは Pull Request 作成時に GitHub Actions が自動で BATS テストを実行します。ワークフローの定義は `.github/workflows/test.yml` を参照してください。`TERM` を `xterm` に設定し、`script` コマンド経由で `bats --formatter pretty --recursive test` を実行することで、CI 環境で出力が重複する問題を防いでいます。
