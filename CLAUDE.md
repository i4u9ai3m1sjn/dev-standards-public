# dev-standards（共通ルール）

dev-standards: 0.4.0

このリポジトリは、複数の製品リポジトリで共通に使う開発ルール・雛形・スクリプトの置き場です。
claude.ai のプロジェクトにこのリポジトリを紐付けると、この CLAUDE.md と `.claude/rules/` が
プロジェクトの全スレッドに読み込まれます。

## 前提にする外部のもの
- Spec Kit（版は `speckit/VERSION`）と superpowers（Project settings > Plugins）だけ。
- それ以外の第三者スキル・プラグインを前提にしない。

## ルールの優先順位
1. 作業中の製品リポジトリの CLAUDE.md・`.claude/rules/`
2. このリポジトリの CLAUDE.md・`.claude/rules/`（共通ルール）

矛盾したら 1 に従い、どちらに従ったかを一言添える。

## 製品リポジトリで作業を始めるとき
- `.dev-standards` ファイルが無い（＝まだ入れていない）リポジトリでは、作業の前に
  `bash <dev-standards のパス>/bootstrap/bootstrap.sh <製品リポジトリのパス>` を提案する。
  実行したら、変更をブランチにコミットして PR にする（main に直接入れない）。
- `.dev-standards` に書かれた版がこの VERSION より古ければ、`--update` を提案する（勝手に実行しない）。
- Spec Kit のスキル（`/speckit-*`）は、クラウド環境のセットアップスクリプト（`setup/setup.sh`）が
  `~/.claude/skills/` に入れている。製品リポジトリの `.claude/skills/` は、プロジェクトのスレッドでは読み込まれない。

## テスト
`.claude/rules/testing.md` に従う（テスト名、受け入れシナリオ番号、Allure・JUnit XML の出し先、証跡の添付、
依存レベル L0〜L4 と置き場所 `tests/l0`〜`l4`、実行タイミング、`manual`、
何をどこまでテストするか＝テストの下限・ISTQB の技法・狭い結合と広い結合、
ミューテーションテスト＝変更したコードの生き残りで落とす・週1回すべて）。

## 進め方
`.claude/rules/flow.md` に従う（brainstorming で地図を作り GitHub Issues に置く、一片＝Spec Kit の feature 1つ＝PR 1本、
実装は writing-plans と subagent-driven-development、converge は最大3回、一片ごとに地図を見直す）。

## コマンドを実行するとき
`.claude/rules/execution-env.md` に従う（流す前にこの環境で流せるかを見る、流せないときや環境のせいで失敗したときは別の実行環境に頼めるかを必ず確かめる、頼み方と範囲、報告の書き方）。

## コミット・PR
`.claude/rules/git.md` に従う（コミットと PR タイトルは Conventional Commits、PR 本文はテンプレートの見出し、
レビューコメントは Conventional Comments、GitHub Actions は actions.lock で固定、
マージは原則人が行い、オーナーがその PR のマージを認めたときだけ AI がマージしてよい）。

## 出典ページの見張り
共通ルールは外部の定義に沿う。出典のページは `sources/` で週1回見張り、変わったら Issue（`source-changed`）になる。
取り込み方は `sources/README.md`。出典を足したら `sources/sources.json` にも足す。

## このリポジトリ自体を変えるとき
- ブランチ＋PR。マージは `.claude/rules/git.md` §6（原則は人。オーナーが認めた PR だけ AI がマージしてよい）。
- `speckit/presets/` か `setup/setup.template.sh` を変えたら `bash setup/build.sh` で `setup/setup.sh` を作り直してコミットする
  （CI が食い違いを検出する）。マージ後、Project settings の Setup script に `setup/setup.sh` を貼り直す。
- `.github/workflows/` を変えたら `gh actions-lock` で `.github/workflows/actions.lock` を作り直してコミットする（`.claude/rules/git.md` §5）。
- 版を上げるときは `VERSION`・この CLAUDE.md 冒頭の版・`CHANGELOG.md` をそろえ、タグ `vX.Y.Z` を付ける。
