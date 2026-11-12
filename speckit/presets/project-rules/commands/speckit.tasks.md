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
