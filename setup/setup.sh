#!/bin/bash
# dev-standards 0.4.0 : claude.ai クラウド環境のセットアップスクリプト
# このファイルは setup/build.sh が作る。直接編集せず setup/setup.template.sh を直す。
# Project settings > Environment > Setup script に、このファイルの中身をそのまま貼る。
#
# やること（root で、Claude Code の起動前に1回。結果はスナップショットされる）
#   1. Spec Kit CLI（specify）を版を固定して入れる
#   2. Spec Kit のスキル（/speckit-*）を dev-standards の preset 付きで ~/.claude/skills/ に入れる
#   3. Allure CLI と Playwright のブラウザを先に取ってきておく（失敗しても続ける）
# 失敗しても環境を壊さないよう、各段の失敗は警告だけにして最後は exit 0 にする。

SPECKIT_VERSION="v1.2.5"
ALLURE_VERSION="3.22.1"
PLAYWRIGHT_VERSION="1.64.1"

log() { echo "[dev-standards setup] $*"; }
export PATH="$HOME/.local/bin:$PATH"

# 1. Spec Kit CLI
if ! command -v uv >/dev/null 2>&1; then
  log "uv を入れます"
  curl -LsSf https://astral.sh/uv/install.sh | sh || log "警告: uv を入れられませんでした"
fi
if command -v uv >/dev/null 2>&1; then
  uv tool install --force "specify-cli @ git+https://github.com/github/spec-kit.git@${SPECKIT_VERSION}" \
    || log "警告: specify-cli ${SPECKIT_VERSION} を入れられませんでした"
fi

# 2. Spec Kit のスキル（preset を当ててから ~/.claude/skills/ へ）
if command -v specify >/dev/null 2>&1; then
  work="$(mktemp -d)"
  preset="$work/preset"
  mkdir -p "$preset"
  mkdir -p "$preset/commands"
  cat >"$preset/commands/speckit.converge.md" <<'DEV_STANDARDS_EOF'
---
description: "Assess the current codebase against the feature's spec, plan, and tasks, then append any remaining unbuilt work as new tasks to tasks.md so implement can complete it. dev-standards: tools/fr_trace.py で FR・受け入れシナリオごとにテストが書かれているかを調べ、テストの無い FR・AC もタスクにする。"
strategy: append
---

## 追加の規則：FR・受け入れシナリオごとのテスト（共通ルール `.claude/rules/testing.md` §8）

コードの評価に加えて、FR と受け入れシナリオ（US<n>/AC<m>）ごとにテストが書かれているかを機械的に調べる。テストは流さない（結果は Allure で見る）。

1. `python3 tools/fr_trace.py --feature <featureディレクトリ名>` を実行し、表を読む。
   `tools/fr_trace.py` が無ければこの節は飛ばし、報告の最後に「dev-standards の `bootstrap.sh --update` で入れる」と書く。
2. 次のとおり Findings に入れる（他の Findings と同じ表・同じ追記の形）。
   - テストが `❌ なし` の FR：gap-type `missing`、source-ref はその FR。タスクは「`[<featureディレクトリ名>/FR-###]` を名前に持つテストを `tests/l<N>/` に足す」（レベルは plan.md の「テストのレベル」に従う）。
   - テストが `❌ なし` の AC：gap-type `missing`、source-ref はその受け入れシナリオ。タスクは「`[<featureディレクトリ名>/FR-###] US<n>/AC<m>` を名前に持ち `@AC` を付けた E2E を `tests/l<N>/` に足す」（FR は tasks.md のその AC のタスクに従う）。
   - 「存在しない feature・FR・AC を指すテストのタグ」：gap-type `contradicts`。タスクは「テスト名のタグを spec.md の FR・受け入れシナリオに合わせる」。
3. コード・テスト・spec・plan は変えない（converge の決まりのまま）。
DEV_STANDARDS_EOF
  mkdir -p "$preset/commands"
  cat >"$preset/commands/speckit.plan.md" <<'DEV_STANDARDS_EOF'
---
description: "Execute the implementation planning workflow using the plan template to generate design artifacts. dev-standards: Project Structure のテストを依存レベル（tests/l0〜l4）で書き、L3 以上に要る秘密情報と実行ワークフローを書く。テストの下限（外部とやり取りする機能に L2 以上、外部サービスには L3 も）と、FR に当てはまる ISTQB の技法を表に書く。"
strategy: append
---

## 追加の規則：テストの構成（依存レベル）

- plan.md の **Project Structure** に書くテストのディレクトリは、テンプレートの `tests/contract/`・`tests/integration/`・`tests/unit/` ではなく、
  共通ルール `.claude/rules/testing.md` §6 の `tests/l0/`〜`tests/l4/` にする（使わないレベルは書かない）。
- Project Structure の後に「テストのレベル」の小節を足し、この feature で作るテストを次の表にする。

  | 機能 | レベル | 依存するもの | 技法 | manual か（理由） | 動かすワークフロー |
  |---|---|---|---|---|---|

- 何をどこまでテストするかは共通ルール `.claude/rules/testing.md` §9 に従う。テストのケースは減らさない（簡単にするのは設計と実装）。「技法」の列には、その機能の FR に当てはまる ISTQB のブラックボックス技法（同値分割法・境界値分析・デシジョンテーブルテスト・状態遷移テスト）とカバレッジ（例：`境界値分析（2値）`）を書く。当てはまる技法が無ければ空欄にする。
- 自分のプロセスの外にある相手（DB・外部 API・キューなど）とやり取りする機能には、その境界を実物か通信越しの代わりに通す L2 以上の行を1つ以上入れる（§9 の下限 2）。
- 相手が自分で管理していない外部のシステム・サービスなら、テスト用の実物に通す L3（広い結合テスト）の行も経路ごとに入れる（§9 の下限 3）。テスト用の環境が無くて入れられないときは、その行の「依存するもの」に理由を書き、L2 で代える。
- L3 以上のテストを作るときは、要る秘密情報（Secrets・Variables の名前だけ。値は書かない）と、動かすワークフロー・`paths` を書く。
- リポジトリの `docs/testing/strategy.md` の対応表に足す行があれば、それもタスクになるように書いておく。
DEV_STANDARDS_EOF
  mkdir -p "$preset/commands"
  cat >"$preset/commands/speckit.tasks.md" <<'DEV_STANDARDS_EOF'
---
description: "Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts. dev-standards: テストタスクに依存レベルの置き場所（tests/l0〜l4）を、E2E テストタスクに受け入れシナリオ番号（US<n>/AC<m>）と @AC を付ける。"
strategy: append
---

## 追加の規則：テストの置き場所（依存レベル）

- テストの置き場所は、テンプレートの `tests/contract/`・`tests/integration/`・`tests/unit/` ではなく、
  共通ルール `.claude/rules/testing.md` §6 の **`tests/l0/`〜`tests/l4/`** を使う。plan.md の Project Structure にレベルの決め方があればそれに従う。
- テストタスクごとに、そのテストが何に依存するかで L0〜L4 を1つ決め、置き場所 `tests/l<N>/` をタスクの説明に書く（迷ったら依存の重い方）。
  - Microsoft の分類どおり。L0：速いメモリ内の単体／L1：対象のコードだけに依存する単体（一時ファイル・サブプロセスなど）／L2：ローカルの DB・ファイルなどを使う分離された機能テスト／L3：テスト用にデプロイしたサービスや外部サービスのテスト用環境に対する機能テスト／L4：本番に対するテスト
  - できるだけ低いレベルで書く
- テストレベル（`.claude/rules/testing.md` §3 の ISTQB の5つ：コンポーネント・コンポーネント統合・システム統合・システム・受け入れ）は、ファイルの置き場所ではなく説明に書く（例：`コンポーネント統合テスト … in tests/l2/test_<機能>_<操作>.py`）。
- plan.md の「テストのレベル」の表の行ごとにテストタスクを作る。「技法」の列に技法が書かれた機能は、その技法とカバレッジで分けたケースをタスクの説明に並べる（例：`境界値分析（2値）: 0件・1件・上限・上限+1`。`.claude/rules/testing.md` §9.1）。
- 既定の実行から外すテスト（人の入力が要る・重い・費用が大きい）は、説明に `manual` と理由を書く。

## 追加の規則：受け入れシナリオとテスト

- spec.md の各ユーザーストーリーの **Acceptance Scenarios** を、上から順に `US<ストーリー番号>/AC<シナリオ番号>` と呼ぶ（例：User Story 1 の 2 番目のシナリオ ＝ `US1/AC2`）。
- 受け入れシナリオごとに、それを確かめる E2E テストのタスクを1つ以上作る。置き場所はそのストーリーのフェーズの最後（実装タスクの後）。
- E2E テストタスクの説明には、テスト名を `[<featureディレクトリ名>/FR-###] US<n>/AC<m> <振る舞い>` の形で書き、`@AC` と明記する。例：
  `- [ ] T020 [US1] E2E @AC: [001-login/FR-005] US1/AC2 ログイン後にダッシュボードへ遷移する in tests/l2/login.spec.ts`
- テストの書き方（ステップ名・添付・タグの付け方）は、共通ルール `.claude/rules/testing.md` に従う。
DEV_STANDARDS_EOF
  mkdir -p "$preset/."
  cat >"$preset/preset.yml" <<'DEV_STANDARDS_EOF'
schema_version: "1.0"
preset:
  id: "project-rules"
  name: "dev-standards project rules"
  version: "0.4.0"
  description: "テストの依存レベル（tests/l0〜l4）と受け入れシナリオ番号（US<n>/AC<m>）を plan・tasks・テスト名に通し、converge で FR・受け入れシナリオごとにテストがあるかを調べる"
  author: "dev-standards"
  license: "MIT"
requires:
  speckit_version: ">=1.2.0"
provides:
  templates:
    - type: "command"
      name: "speckit.tasks"
      file: "commands/speckit.tasks.md"
      description: "Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts. dev-standards: テストタスクに依存レベルの置き場所（tests/l0〜l4）を、E2E テストタスクに受け入れシナリオ番号（US<n>/AC<m>）と @AC を付ける。"
      strategy: "append"
    - type: "command"
      name: "speckit.plan"
      file: "commands/speckit.plan.md"
      description: "Execute the implementation planning workflow using the plan template to generate design artifacts. dev-standards: Project Structure のテストを依存レベル（tests/l0〜l4）で書き、L3 以上に要る秘密情報と実行ワークフローを書く。テストの下限（外部とやり取りする機能に L2 以上、外部サービスには L3 も）と、FR に当てはまる ISTQB の技法を表に書く。"
      strategy: "append"
    - type: "command"
      name: "speckit.converge"
      file: "commands/speckit.converge.md"
      description: "Assess the current codebase against the feature's spec, plan, and tasks, then append any remaining unbuilt work as new tasks to tasks.md so implement can complete it. dev-standards: tools/fr_trace.py で FR・受け入れシナリオごとにテストが書かれているかを調べ、テストの無い FR・AC もタスクにする。"
      strategy: "append"
tags:
  - "testing"
DEV_STANDARDS_EOF
  (
    cd "$work" && mkdir repo && cd repo && git init -q \
      && specify init --here --integration claude --script sh --force \
      && specify preset add --dev "$preset"
  ) >"$work/init.log" 2>&1 || { log "警告: specify init / preset に失敗しました"; tail -20 "$work/init.log"; }
  if ls "$work/repo/.claude/skills"/speckit-* >/dev/null 2>&1; then
    mkdir -p "$HOME/.claude/skills"
    rm -rf "$HOME/.claude/skills"/speckit-*
    cp -R "$work/repo/.claude/skills"/speckit-* "$HOME/.claude/skills/"
    log "Spec Kit のスキルを入れました: $(ls -d "$HOME/.claude/skills"/speckit-* | xargs -n1 basename | tr '\n' ' ')"
  fi
  rm -rf "$work"
fi

# 3. Allure CLI と Playwright のブラウザ（npx のキャッシュに入れておく）
if command -v npx >/dev/null 2>&1; then
  timeout 120 npx -y "allure@${ALLURE_VERSION}" --version >/dev/null 2>&1 \
    || log "警告: allure@${ALLURE_VERSION} を取ってこられませんでした"
  timeout 150 npx -y "playwright@${PLAYWRIGHT_VERSION}" install chromium >/dev/null 2>&1 \
    || log "警告: Playwright ${PLAYWRIGHT_VERSION} のブラウザを入れられませんでした（ネットワーク許可を確認）"
fi

log "完了"
exit 0
