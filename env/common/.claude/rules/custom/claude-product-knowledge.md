# Claude Product Knowledge

> このファイルは Claude Code（CLI）、Claude Agent SDK、Claude API（旧 Anthropic API）、
> Anthropic 公式 SDK に関する事実確認のルールを定義します。

## ルール

Claude 製品の **機能・オプション・挙動・存在の有無** について断定する前に、
必ず一次情報で確認すること。

学習データに基づく知識のみで「ある／ない」「こう動く／こう動かない」を
断言してはならない。

## Why

- Claude 製品は頻繁にアップデートされるため、学習データ時点で存在しなかった
  機能・オプションが現在は存在することがある。
- 「存在しない」と断定する誤りはユーザーの選択肢を奪うため、特に害が大きい。
- 過去に `claude --worktree` フラグを「存在しない」と断定して誤った経緯がある
  （実際は `-w, --worktree [name]` として存在した）。同種の事故を防ぐためのルール。

## How to apply

質問・依頼を受けた時、対象が以下のどれかに該当するなら、答える前に一次情報を確認する:

- Claude Code CLI のフラグ・コマンド・設定・hook・skill・MCP の挙動
- Claude Agent SDK のクラス・関数・引数・動作仕様
- Claude API（Anthropic API）のエンドポイント・パラメータ・モデル仕様
- Anthropic SDK（Python / TypeScript 等）の使い方・型・バージョン差異

### 確認手段（優先順）

1. **`claude-code-guide` エージェントに委譲する** — Claude Code / SDK / API 専門の
   調査エージェント。`Bash`, `Read`, `WebFetch`, `WebSearch` を持ち、訓練データに
   依存せず現行ドキュメント・実装で答える。
2. **`claude --help`, `claude <subcommand> --help`** をローカルで実行する。
3. **公式ドキュメント** を WebFetch で直接読む。
   - https://docs.claude.com/
   - https://docs.anthropic.com/
4. **Context7 MCP** でライブラリドキュメントを取得する（SDK の場合）。

### 禁止表現

確認していない事項について「たぶん」「おそらく」「〜のはずです」で答えない。
確認できたことと確認できていないことを明確に分けて報告する。

「存在しない」を主張する場合は、その根拠（`--help` の出力、ドキュメントの該当箇所など）
を必ず添える。
