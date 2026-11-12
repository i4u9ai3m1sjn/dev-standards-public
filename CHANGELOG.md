# CHANGELOG

## Unreleased
- 共通ルール `git.md` §6「マージ」：マージは原則として人が行い、オーナーがその PR のマージを明示して認めたときだけ AI エージェントがマージしてよい。マージ前に必須のチェック・未解決のレビュー・衝突を確かめる。CLAUDE.md と `flow.md` §2 の 5 はこれを参照する。
- 公開リポジトリへの公開：タグ `v*` の push か手動実行で、中身を1コミットにして公開リポジトリ（Variables の `PUBLIC_REPO`）の `main` を force push で置き換える `publish-public` ワークフロー。変更の履歴は出さない。出さないファイルは `.gitattributes` の `export-ignore`（`.github/`）。準備は README の「公開リポジトリ」。
- preset `project-rules` の `repository:`（説明だけの項目で、Spec Kit の検証では任意）を消す。`setup/setup.sh` も作り直したので、マージ後は Setup script を貼り直す。
- テストのワークフローの雛形（`test-report.yml`・`test-l3.yml`）で、テストの実行・FR ごとのテストの有無・Allure レポートを別のジョブにする：`test` が `out/allure-results/` を artifact `allure-results` として上げ、`report`（`needs: test`、テストが落ちても作る、テストのジョブが動かなかったときは作らない）が受け取って1ファイルにする。`fr-trace` は依存を入れずに並べて動く。`templates/github/allure-steps.yml`（手順の差し込み）は `allure-report-job.yml`（report ジョブの雛形）に置き換える。`test-l3.yml` のテストのジョブ名は `test-l3` から `test` になる（PR の必須チェックには入れていないので Branch protection は変わらない）。testing.md §6.4 に1文。
- 新しく `actions/download-artifact@v8.0.2` を使う。製品リポジトリでワークフローを置き直したら `gh actions-lock` で `actions.lock` を作り直す（git.md §5）。
- 既に `test-report.yml`・`test-l3.yml` があるリポジトリでは、`bootstrap.sh` がジョブを分ける手順を残りの手順に出す（上書きしない）。

## 0.4.0（2026-11-07）
マージ後は Project settings の Setup script に `setup/setup.sh` を貼り直し、各リポジトリで `bootstrap.sh --update` を流す。
- 共通ルール `testing.md` §10「ミューテーションテスト」：StrykerJS（Vitest）と mutmut 3 で、殺す側のテストは L0〜L2。PR と main への push は前回の結果を使い回して変更したコードだけ、週1回と手動実行はすべて流す。変更したコードに生き残り（Survived・NoCoverage など）が1つでもあれば落とし、全体のスコアでは落とさない。等価ミュータントは理由付きの除外コメントでだけ外す。証跡は `out/mutation/`（Stryker の HTML・JSON、mutmut の生き残りと差分）を成果物にし、ジョブサマリーに変更分の表を出す。Allure には入れない。§6.4 の表に1行。
- 雛形：`.github/workflows/mutation.yml`（Python・Node・両方）、`tools/mutation_gate.py`（変更した行・関数とミュータントを突き合わせて判定。標準ライブラリだけ）、Node は `stryker.config.json`・`vitest.mutation.config.ts`。bootstrap.sh が置き、Python は `.gitignore` に `mutants/` を足して `[tool.mutmut]` を残りの手順に出す。`bootstrap/selftest.sh` で判定と mutmut の実行を確かめる。
- 共通ルール `flow.md` §2 の 3：実装の最後に、変えたファイルにミューテーションテストを流して生き残りにテストを足す。
- 共通ルール `testing.md` §9「何をどこまでテストするか」：目的は「テストが通った＝ちゃんと動く」と言えること。下限は「各 FR にテスト・各 AC に `@AC` の E2E」「自分のプロセスの外の相手とやり取りする FR に、境界を実物か通信越しの代わりに通すテスト（L2 以上）」「自分で管理していない外部のシステム・サービスには、テスト用の実物に通す広い結合テスト（L3）も経路ごとに」の3つ。ケースの分け方は ISTQB Foundation v4.0 のブラックボックス技法（同値分割法・境界値分析・デシジョンテーブルテスト・状態遷移テスト）を当てはまる FR で使い、シラバスの基本のカバレッジ以上にする。結合の範囲は Martin Fowler の狭い結合・広い結合と ISTQB のコンポーネント統合・システム統合で呼び分ける。
- 共通ルール `testing.md` §3：「単体・結合・E2E」を ISTQB Foundation v4.0 のテストレベル（コンポーネント・コンポーネント統合・システム統合・システム・受け入れ）に置き換え、レベルごとの証跡を決めた。E2E はシステムテストと受け入れテストの行い方（利用者の入口から通す）として残す。L0〜L4・置き場所・`fr_trace.py` は変わらない。
- 共通ルール `flow.md` §2：設計と実装は今の一片に要る分だけにする（YAGNI）。テストはこれに含めない。
- preset `project-rules` 0.4.0：plan の「テストのレベル」の表に「技法」の列を足し、外部とやり取りする機能に L2 以上の行、外部サービスには L3 の行を求める。tasks は表の技法とカバレッジで分けたケースをテストタスクに並べる。マージ後は Setup script の貼り直しと、各リポジトリでの `bootstrap.sh --update` が要る。
- 共通ルール `execution-env.md` を「実行環境が足りないとき」から「コマンドを実行するとき」のルールに改める：コマンドを流す前に、この環境で流せるか（無いもの・繋がらない相手・入れてはいけないツールが要るか）を見る。流せない・環境のせいで失敗した・試さずにオーナーに任せる、のどれでも、オーナーに手順を渡す前に別の実行環境に頼めるか（§2）を必ず確かめ、その結果を報告に書く。ファイル名は変えない。

## 0.3.0（2026-11-03）
マージ後は Project settings の Setup script に `setup/setup.sh` を貼り直し、各リポジトリで `bootstrap.sh --update` を流す。
- FR・受け入れシナリオごとのテストの有無 `tools/fr_trace.py`（testing.md §8）：spec.md の FR と受け入れシナリオ（`US<n>/AC<m>`）を、`tests/l0`〜`l4` のファイルに書かれた `[<feature>/FR-###]`（と同じ行の `US<n>/AC<m>`）と突き合わせ、テストのあるレベルを表にする。テストは流さず結果も見ない（結果は Allure で見る）。Status が `Implemented` の feature にテストの無い FR・AC があるか、タグが存在しない FR・AC を指すと終了コード 1。bootstrap.sh が `tools/fr_trace.py` を置き、test-report.yml の雛形が流してジョブサマリーに表を出す（既に test-report.yml があるリポジトリでは、足す手順を残りの手順に出す）。
- preset `project-rules` 0.3.0：converge に追記を足し、`tools/fr_trace.py` を実行して、テストの無い FR・AC と、存在しない FR・AC を指すテストのタグもタスクにする。マージ後は Setup script の貼り直しと、各リポジトリでの `bootstrap.sh --update` が要る。
- flow.md：一片の PR を仕上げるときに spec.md の Status を `Implemented` にする。
- 共通ルール `flow.md`（進め方）：エピックごとに brainstorming で地図を作り GitHub Issues（エピック＋一片ごとのサブ Issue）に置く。一片＝Spec Kit の feature 1つ＝PR 1本で、spec の承認と計画の確認をドラフト PR のコメントで受けてから、writing-plans と subagent-driven-development で実装し、converge は最大3回。一片ごとに Allure の `@AC` で確かめて地図を見直す。`/speckit-implement` と superpowers の executing-plans・using-git-worktrees・finishing-a-development-branch は使わない。
- 共通ルール `.claude/rules/execution-env.md`：環境のせいでコマンドが失敗したら、やり直す前に別の実行環境（オーナーの手元の機械に繋がったエージェントなど）に頼めるか確かめ、頼む範囲と報告の形を決める。エージェントの種類や動く場所に依存しない書き方にする。

## 0.2.0（2026-11-01）
互換性を壊す変更を含む（テストの置き場所が `tests/l0`〜`l4` になった）。既存のリポジトリは `bootstrap.sh --update` と、下の「テストのワークフロー」の手作業が要る。
- テストのワークフローの雛形を testing.md §6.4 に合わせる：`test-report.yml` は L0〜L2 だけ（pytest は `-m "not l3 and not l4"`、Node は `tests/l0 tests/l1 tests/l2`）。L3 は新しい `test-l3.yml`（PR は `paths` で絞る・Dependabot とフォークの PR では動かさない・main への push と週1回と手動実行ではすべて）。どちらもテストが無ければ緑で終わる。既に `test-report.yml` があるリポジトリでは、bootstrap.sh が「L3 を分ける」を残りの手順に出す。
- testing.md §6.4 の L3 ジョブの `if:` を、push・定期実行でも動く形（`github.event_name != 'pull_request' || …`）にする。
- Python と Node が両方あるリポジトリでは、pytest と Vitest・Playwright を両方流す雛形を置く（今までは Node だけだった）。
- Python の依存の入れ方を、`pyproject.toml` の `optional-dependencies.dev` があれば `.[dev]`、無ければ `requirements-dev.txt`・`requirements.txt`・`-e .` の順で選び、推測したときは確かめる手順を出す。
- `levels.py` が marker `ac` も登録する（残りの手順から「ac を登録する」を外す）。
- Allure レポートのファイル名にジョブ名を入れる（`allure-report-<job>-<run>.html`。1つのワークフローに複数のテストジョブがあっても重ならない）。テスト結果が無くても空のレポートを作る。
- `bootstrap/selftest.sh`：試験用リポジトリに bootstrap.sh を流して確かめる。`ci.yml` で流す。
- 共通ルール `testing.md` §6：テストの依存レベル L0〜L4（Microsoft の DevOps のテスト分類をそのまま使う）、例外フラグ `manual`（Bazel の `manual` と同じ意味で、`RUN_MANUAL=1` のときだけ実行）、置き場所 `tests/l0`〜`l4`（ディレクトリ＝レベル、ファイル名＝機能）、既定の実行タイミング（L0〜L2 は PR と main、L3 は PR では変更した機能だけ・共通コードの変更ではすべて・Dependabot とフォークでは動かさない・main への push と週1回はすべて、L4 は本番デプロイ後）、テストを流すワークフローはすべて Allure を出す、各リポジトリの `docs/testing/strategy.md` に書くこと。§3 の「レベル」は「種類」に言い換え。
- 雛形：pytest 用 `levels.py`（置き場所から marker `l0`〜`l4` を付け、`manual` を既定で外す。`--require-level` で置き場所の外のテストを収集エラーにする）を bootstrap.sh が置き、`pytest_plugins` に足す。Vitest・Playwright の設定を `tests/l0`〜`l4` に合わせ、Playwright は `@manual` を既定で外す。
- preset `project-rules` 0.2.0：tasks はテストの置き場所を `tests/l0`〜`l4` にする。plan にも追記を足し、Project Structure のテストを `tests/l0`〜`l4` で書き、「テストのレベル」の表を作る。マージ後は Setup script の貼り直しと、各リポジトリでの `bootstrap.sh --update` が要る。
- リポジトリ直下に `.gitignore`（`__pycache__/`）。
- 出典ページの見張り：`sources/`（`watch.py`・`sources.json`・本文の写し）と `watch-sources` ワークフロー（毎週月曜、変わったら Issue `source-changed` に差分）。最初の対象は Microsoft の DevOps のテスト分類と Bazel の共通属性（testing.md §6 の出典）。
- preset `project-rules`：`speckit-tasks` スキルの description が追記の説明だけに置き換わっていたので、Spec Kit 本来の説明を残して追記の説明を後ろに足す。

## 0.1.0（2026-10-31）
- 最初の版。前提は Spec Kit v1.2.5 と superpowers だけ。
- 共通ルール：`CLAUDE.md`、`.claude/rules/testing.md`（テスト名に `[<feature>/FR-###]` と `US<n>/AC<m>`、`@AC`、「期待: 」ステップ、レベルごとの証跡、`out/allure-results` と `out/junit*.xml`）。
- Spec Kit preset `project-rules`：tasks の E2E テストタスクに受け入れシナリオ番号と `@AC` を付ける。
- `setup/setup.sh`：クラウド環境で Spec Kit CLI とスキル（preset 込み）を `~/.claude/skills/` に入れる。
- `bootstrap/bootstrap.sh`：製品リポジトリに `.specify/`・preset・`allurerc.mjs`・言語ごとの雛形・`.gitignore`・`.dev-standards` を入れる。
- コミット・PR の書き方：`.claude/rules/git.md`（Conventional Commits、PR タイトルも同形式、本文は Google eng-practices 流の型、レビューコメントは Conventional Comments）。PR テンプレートと PR タイトル確認 CI（`amannn/action-semantic-pull-request@v6`）を bootstrap.sh が配る。
- GitHub Actions は `actions.lock`（gh actions-lock v0.4.0）で固定。`verify-lockfile` CI と Dependabot 設定を bootstrap.sh が配る。
- 雛形：`allurerc.mjs`（1ファイル・日本語）、Playwright・Vitest の設定、CI の Allure 手順、pytest 用 `allure_support.py`。
