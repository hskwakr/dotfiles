# tmux-snapshot

`bin/tmux-snapshot.sh` は、現在の tmux セッション・ウィンドウ・ペイン構成と各ペインの作業ディレクトリ（cwd）を JSON として保存し、後から復元するためのスクリプトです。macOS のアップデートや再起動の前に明示的に状態を保存し、復帰後に 1 コマンドで元のレイアウトに戻すことを目的としています。

## 設計方針

- **保存タイミング**: 明示実行のみ（自動保存・常駐プロセスなし）
- **復元対象**: セッション名・ウィンドウ構成・各ウィンドウの `window_layout`・各ペインの cwd
- **外部依存**: `tmux` と `jq` を利用します。tmux-resurrect / tmux-continuum は導入しません。

`pane_current_command` は保存対象に含めません。ペイン内で動いていたコマンドを復元すると意図しない再実行や副作用が発生するため、cwd のみ復元する設計としています。

## 使い方

```sh
bin/tmux-snapshot.sh save                   # 現在の状態を保存
bin/tmux-snapshot.sh restore                # 最新スナップショットから復元
bin/tmux-snapshot.sh restore --from FILE    # 指定したファイルから復元
bin/tmux-snapshot.sh list                   # 保存済みスナップショットを新しい順に一覧表示
bin/tmux-snapshot.sh -h                     # ヘルプ
```

### 保存先

スナップショットは `backups/tmux/snapshot_YYYYMMDD_HHMMSS.json` という形式で保存されます。最大 10 世代を保持し、上限を超えると古いものから削除されます。

### 復元時の挙動

`restore` 実行時に、保存済みスナップショットに含まれるセッション名のいずれかが既に tmux サーバー上に存在する場合、**衝突として中止します**。これは「再起動直後に明示的に復元する」本来のユースケースを優先し、既存セッションを誤って上書きしないための仕様です。

衝突が起きた場合は、`tmux kill-session -t <name>` などで既存セッションを整理してから再度 `restore` を実行してください。

### 復元される項目

- セッション名
- ウィンドウの順序・名前・レイアウト（分割比）
- 各ペインの cwd

復元されないもの:

- ペイン内で動いていたコマンド
- スクロールバッファ
- 環境変数や `$TMUX` 起源の状態
- 保存時のウィンドウ／ペインの**数値インデックス** — 保存値は記録のみで、復元時は配列順序に従って `base-index` / `pane-base-index` に基づいた連続したインデックスで作り直されます。これは「ウィンドウ 0/1/2 を閉じて 3/5 だけ残った」ような非連続な保存状態でも素直に復元できるようにするための仕様です。

## 例

```sh
# OS アップデート前に保存
bin/tmux-snapshot.sh save

# 再起動後にツリーを復元
bin/tmux-snapshot.sh restore

# 過去のスナップショットを確認
bin/tmux-snapshot.sh list

# 古いスナップショットを指定して復元
bin/tmux-snapshot.sh restore --from backups/tmux/snapshot_20260519_223000.json
```

## ファイル形式

JSON のスキーマは次のとおりです。

```json
{
  "version": 1,
  "saved_at": "2026-05-20T10:30:00Z",
  "sessions": [
    {
      "name": "work",
      "windows": [
        {
          "index": 0,
          "name": "main",
          "layout": "abc1,200x50,0,0[200x25,0,0,1,200x24,0,26,2]",
          "panes": [
            { "index": 0, "cwd": "/Users/akira/dev" },
            { "index": 1, "cwd": "/Users/akira/dev/foo" }
          ]
        }
      ]
    }
  ]
}
```

`saved_at` は ISO-8601（UTC）形式、`layout` は `tmux list-windows -F '#{window_layout}'` の出力をそのまま保持します。

## 関連

- 元の検討経緯: [issue #99](https://github.com/hskwakr/dotfiles/issues/99)
- バックアップ全般の仕組み: [dotfiles プロジェクト](./dotfiles.md)
