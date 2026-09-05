# User-Level Instructions (akira)

このファイルは Claude Code が user memory として自動読み込みする
全プロジェクト共通の指示です。プロジェクト固有のルールは各プロジェクトの
`CLAUDE.md` / `AGENTS.md` に書きます。

## 共通ルール（言語非依存）

@rules/common/coding-style.md
@rules/common/git-workflow.md
@rules/common/security.md
@rules/common/testing.md
@rules/common/development-workflow.md
@rules/common/code-review.md
@rules/common/agents.md

## カスタムルール（自分専用）

`~/.claude/rules/common/` は upstream 由来の資産をそのまま保つ層なので、
自分で追加するルールは `~/.claude/rules/custom/` 配下に置き、ここから import する。

@rules/custom/playwright-route.md
@rules/custom/claude-product-knowledge.md

## 言語別・ドメイン別ルール

`~/.claude/rules/{python,typescript,golang,php,web}/` 配下のルールは
**ここでは import しない**。必要なプロジェクトの `CLAUDE.md` / `AGENTS.md`
側で明示的に `@~/.claude/rules/<lang>/...` を import する。

理由:

- 全プロジェクトに全言語ルールを常時ロードするのはトークン浪費で、
  関係ない言語の指示が混ざるとノイズになる。
- プロジェクトの言語・ドメインはプロジェクト側が一番よく知っている。

## ルールの優先順位

`rules/common/` と言語別ルールが衝突したら、**言語別ルールが優先**する
（specific が general を上書きする）。common 側で上書きされうる項目には
「Language note」が付いている。

## rules / skills の実体

`~/.claude/rules/` と `~/.claude/skills/` は
[hskwakr/dotfiles](https://github.com/hskwakr/dotfiles) への symlink。
ここを編集すると dotfiles の作業ツリーが変わるので、直したら dotfiles 側で
コミットする。
