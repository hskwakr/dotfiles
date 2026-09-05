---
name: work-recall
description: ある1日に何をやったかを、ローカル git リポジトリのコミット履歴・PR 状態・作業ノート（task-notes など）の session-log から抽出し、構造化サマリとして返すステートレスなスキル。input は日付（省略時は前日）、outcome はその日の作業サマリ。ファイル書き込み・コミット・整形・分類はしない。「昨日やったこと」「日報の素材」「この日の作業まとめ」や日付指定で使う。出力は日報・週次レビュー・standup の素材になる。
argument-hint: "[YYYY-MM-DD（省略時は前日）]"
---

# 作業の想起スキル (work-recall)

ある1日に**実際に何をやったか**を、コミット履歴・作業ログという一次情報から再構成し、
構造化サマリとして返す。記憶や憶測でなく、**ログに残った事実だけ**を材料にする。

- **本質**: 自分の作業を、記憶に頼らず一次情報から正直に想起（recall）するためのプリミティブ。
- **ステートレス**: input = 対象日。outcome = その日の作業サマリ（テキスト）。
- **副作用なし**: ファイルを書かない・コミットしない・整形しない・分類しない。
  それらは呼び出し側（日報作成・週次レビュー等）の責務。
- outcome は日報・週次レビュー・standup などの**素材**として使える。

## 入力

- 対象日: 引数があればその日付。なければ**前日**（`currentDate` − 1 日）。ISO `YYYY-MM-DD`。
- 単日のみを対象とする（期間集計が必要なら、呼び出し側が日ごとに複数回呼ぶ）。

## 材料源（既定・環境に合わせて読み替える）

**ローカル git を正とする。** GitHub の検索経路は補助に留める（理由は下の「GitHub 検索を主経路にしない理由」）。

1. **ローカルリポジトリ（主経路）**: `~/ghq` 配下の全リポジトリ。ブランチ・push の有無・public/private を問わず当日の作業が残る。
2. **PR の状態**: `gh pr list` / `gh pr view`。PR 番号・draft/open はローカル git から分からないので gh で確定させる。
3. **作業ノートリポジトリ**: `~/ghq/github.com/hskwakr/task-notes`（draft PR で進む個人タスクノート。
   `session-log.md` / `progress.md` / `decision-log.md` に "〜回目でやったこと" 形式の日次ログが溜まる）。
   コミット件名だけでは「何が決まったか」が読めないので直読して補う。
4. **GitHub 活動（補助）**: `mygh-day <YYYY-MM-DD>`（Commits / PRs / Issues を日付集計する自作シェル関数）。
   他マシンでの作業や、ローカルに clone していないリポの取りこぼしを拾う保険。

別の材料源（他リポの作業ログ、別の集計ツール）があれば同じ要領で追加してよい。

## 手順

### 1. 当日コミットのあったリポジトリを特定する（主経路・推測で書かない）

```bash
for d in $(find ~/ghq -maxdepth 4 -name .git -type d 2>/dev/null); do
  r=$(dirname "$d")
  n=$(cd "$r" && git log --all --since="<date> 00:00" --until="<date> 23:59:59" --pretty=oneline 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && echo "$n $r"
done
```

ヒットした各リポで当日のコミットを列挙する。**`--all` を必ず付ける**（作業は PR ブランチ上で進むため）。

```bash
git log --all --since="<date> 00:00" --until="<date> 23:59:59" \
  --pretty=format:'%h %ad %an %s' --date=format:'%H:%M'
```

- 複数人リポでは `%an` で自分の commit を選別する（他メンバーの merge commit が混ざる）。
- 変更規模を見るときは `git show --stat <hash>`。

### 2. PR の状態を gh で確定させる

```bash
gh pr list --repo <owner/repo> --author @me --state all --limit 10 \
  --json number,title,isDraft,createdAt,updatedAt
```

PR 番号と draft/open を**ノートの記述からではなく gh から取る**。ノート側の記述は古いことがある。

### 3. 作業ノートから「何が決まったか」を読む

- `git log --all` で当日のノートコミットを列挙。
- 各コミットの `session-log.md` / `progress.md` / `decision-log.md` を読む。
  差分だけなら `git show <hash> -- '*session-log.md'`、全文なら `git show <hash>:<path>`。

### 4. 構造化サマリに落とす

集めた材料を、タスク単位で要約する。作業手順をそのまま転記せず「**だから何が進んだか**」に翻訳する。
事実（ファイル名・行番号・確定した結論・数値）は残し、**ログに無いことは書かない**。

## GitHub 検索を主経路にしない理由

`mygh-day` は `gh search commits` に依存しており、**GitHub のコミット検索はデフォルトブランチしか索引しない**。

> When you search for commits, only the default branch of a repository is searched.
> — GitHub Docs / Searching commits

PR ブランチ上で作業する運用では、**マージされるまで当日のコミットが 1 件も出てこない**。
2026-08-17 の実測では `mygh-day 2026-08-17` が Commits / PRs / Issues すべて 0 件で、
その日の作業（task-notes の 2 タスク + 業務リポの 5 コミット）は全て PR ブランチ上にあった。

- private リポジトリだから出ないわけでは**ない**（private でもデフォルトブランチのコミットは検索に出る）。
- `mygh-prs` は `--updated` で絞るため、**当日作成でも更新が翌日なら出てこない**。PR は `gh pr list` で取ること。
- `gh search prs` の `--json repository` は private リポで `null` を返し、リポ名が失われる。

## 出力フォーマット（outcome）

```
## <YYYY-MM-DD> やったこと

### <タスク名>（status: 完了 / 進行中）
- やったこと: <一次情報から要約した前進内容>
- 確定した事実: <ファイル名・行番号・決定事項・数値など>
- 詰まった点 / 解決: <あれば>
- 学び・気づき: <あれば>

### <次のタスク名>（status: ...）
...
```

- 材料が特定の経路にしか無い場合は、その**出所も添える**（どこから拾ったか）。
- 該当日に作業ログが見つからない場合は、推測で埋めず「ログ上は <観測された範囲> のみ」と正直に出す。

## 注意: ログの一人称は本人ではない

`task-notes` の `session-log.md` は Claude がセッション記録として書いており、**利用者本人が三人称で登場する**
（「金田が決定した」「本人が再現した」など）。また「claude の記述の誤り」は利用者本人の誤りではない。

このスキルは**ログに書かれた事実をそのまま返すプリミティブ**なので、視点の変換はしない。
一人称に直すのは呼び出し側の責務。ただし出力を読む側が誤解しないよう、**三人称のまま引いた箇所はその旨が分かる形**にする。

## スコープ外（このスキルはやらない）

- 日報などの所定フォーマットへの整形 → 呼び出し側
- ラベル付け・分類（業務/個人 など）、タスク名の簡略化 → 呼び出し側
- 視点の反転（三人称 → 一人称）、所感・学びの付与 → 呼び出し側
- ファイル書き込み・コミット・push → 呼び出し側
