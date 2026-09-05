# Playwright Route

## Default Route: `playwright-cli` skill

Playwright を使うすべてのブラウザ自動化作業（navigate / cookie セット / スクリーンショット取得 / ブラウザバック検証 / フォーム入力 など）は、**`playwright-cli` skill を `Skill` ツール経由で呼ぶ**ことを既定とする。

## Do NOT

- `mcp__playwright__*` ツールを直接呼ばない（playwright MCP サーバーが接続済みで利用可能でも、それを最初の選択肢にしない）
- `mcp__plugin_everything-claude-code_playwright__*` 系の MCP ツールも同様に直接呼ばない
- skill 名 `playwright-cli` を見て「中身が MCP なのか CLI なのか」を推測して経路を変えない。skill の中身は skill 側に任せる

## When to deviate

`playwright-cli` skill 経由で要件を満たせない明確な根拠がある場合のみ、直接 MCP ツールを呼ぶ。その場合は事前にユーザーに確認してから例外的に進める。

## Why

複数のプロジェクト・複数のセッションで Playwright を使う場面のたびに、「playwright-cli を使ってほしい」とユーザーが訂正する事象が繰り返されていた。同じ訂正をセッション横断で続けさせない目的でこのルールを置く。
