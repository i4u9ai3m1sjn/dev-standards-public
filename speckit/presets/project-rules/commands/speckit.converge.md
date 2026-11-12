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
