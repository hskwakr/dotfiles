# テスト実行ガイド

このドキュメントでは、Docker またはローカルにインストールした BATS を利用してテストを実行する方法を説明します。

## 前提条件
- Docker が利用できる、もしくは BATS がインストールされていること

## 実行方法
### Docker を使う場合
1. `test/` ディレクトリで Docker イメージをビルドし、BATS を実行します。
   ```sh
   cd test
   ./run_tests.sh sample.bats
   ```
2. 任意の `*.bats` ファイルを引数に指定することで、個別のテストを実行できます。

Docker イメージは `bats/bats:latest` をベースにしており、ビルド時にリポジトリ全体を `/work` にコピーします。そのため、実行時にボリュームマウントを指定する必要はありません。

### ローカルに BATS をインストールする場合
1. Debian 系の場合は `apt-get install bats`、macOS なら `brew install bats-core` を実行します。
2. その後、リポジトリ直下で次のように実行します。
   ```sh
   bats test/sample.bats
   ```
3. 複数のテストをまとめて実行する場合はワイルドカードを利用できます。
   ```sh
   bats test/*.bats
   ```

## CI での自動実行

このリポジトリでは Pull Request 作成時に GitHub Actions が自動で BATS テストを実行します。ワークフローの定義は `.github/workflows/test.yml` を参照してください。
