# 開発の進め方（dev-standards 共通）

目的：設計を「利用者にとって意味のある機能の薄い一片」に分け、一片ごとに
「その分だけ設計する → 作る → 動くものを確かめる → 地図を直す」を回す。
最初に全部を設計しない。先の一片は粗いまま置き、作る直前にその一片の分だけ詳しくする。

## 1. 地図（エピックごとに1回）

- 新しいエピックは superpowers の brainstorming で設計文書を書く（既定の `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`）。中身は次の4つに絞る。
  1. 目的と、利用者がたどる大きな流れ
  2. 一片の一覧と順番。各一片に「これが終わると何を確かめられるか」を1行。1つ目は端から端まで一応つながる最小のもの（ウォーキングスケルトン）
  3. 後から変えると高くつく判断（データの骨格、外部との境界、技術スタック）
  4. まだ決めないこと
- 地図の生きた版は GitHub Issues に置く。
  - エピックの Issue を1つ。本文に設計文書へのリンク、目的、後から変えると高くつく判断。
  - 一片ごとにサブ Issue。本文に「これが終わると何を確かめられるか」。**サブ Issue の並び順が作る順番**。
  - 人の承認はエピックの Issue へのコメントで記録する。
- 設計文書が承認されたら writing-plans は呼ばない（brainstorming の既定の次の手順より、このルールを優先する）。地図の最初の一片について 2 に進む。
- 一片の割り方の例：操作の経路ごと（正常系を先に、例外は後の一片）、扱うデータの種類ごと、業務ルールごと、入口（画面・API）ごと。分からない所は調査だけの一片で先に確かめる。

## 2. 一片（＝Spec Kit の feature 1つ、PR 1本）

一片の目安：ユーザーストーリー 1〜3、FR 10 前後まで。超えそうなら、地図に戻って一片を割ることを人に提案する。

1. **spec**：`/speckit-specify` に一片のサブ Issue と設計文書のパスを渡し、その一片の分だけ書く。`/speckit-clarify`、`/speckit-checklist` を回す。
   spec をコミットしてドラフト PR を作り、人に spec の承認を頼む（承認は PR のコメント）。承認までは 2 に進まない。
2. **計画**：`/speckit-plan`（設計文書のパスも渡す）、`/speckit-tasks`、`/speckit-analyze`（CRITICAL が 0 件）。
   コミットして、人に plan.md の「テストのレベル」の表と tasks.md の `@AC` のタスクの確認を頼む（PR のコメント）。確認までは 3 に進まない。
3. **実装**：superpowers の writing-plans で、spec.md・plan.md・tasks.md を読んで一片の plan を書く（既定の `docs/superpowers/plans/`）。
   テスト名と置き場所は tasks.md と `.claude/rules/testing.md` のとおりにする。
   plan は subagent-driven-development で実行する。終わったタスクは tasks.md でも `[X]` にする。
   実装の最後に、変えたファイルにミューテーションテストを流し、生き残りにテストを足す（`.claude/rules/testing.md` §10。CI は変更したコードの生き残りで落とす）。
4. **収束**：`/speckit-converge` を回す（preset により、`tools/fr_trace.py` で FR・受け入れシナリオごとにテストがあるかも調べる。testing.md §8）。最大3回（実行前に tasks.md の `## Phase N: Convergence` を数え、2つ以上なら今回が最後。今回も追記が出たら実装せず人に報告する）。
   追記が出たら writing-plans の plan に足して 3 と同じく実装する。頼まれていない実装（unrequested）は消さず、PR 本文の「概要」に書く。
5. **PR**：spec.md の `**Status**:` を `Implemented` にする（以後、CI の `tools/fr_trace.py` が、テストの無い FR・受け入れシナリオを見つけると落とす）。本文は `.claude/rules/git.md` の形。「なぜ」に spec へのリンクと `Closes #<一片のサブ Issue>`、
   「確かめ方」に Allure で見てほしい `US<n>/AC<m>`。ドラフトを解除してレビューを頼む。マージは `.claude/rules/git.md` §6（原則は人。オーナーが認めたときだけ AI がマージする）。

- 作っている途中で、この一片では作れない FR・受け入れシナリオがあると分かったら（外部の API がまだ無いなど）、spec から外して地図の次の一片（サブ Issue）に移し、人に伝える。テストを「対象外」にする印は作らない。
- 一片が大きく spec を先に main に入れたいときは、spec だけの PR を先に出してよい（その後の 2〜5 は別の PR）。
- 使わないもの：`/speckit-implement`（実装の指示書は writing-plans の plan）、superpowers の executing-plans・using-git-worktrees・finishing-a-development-branch。セッションのブランチで作業する。
- 実装中の規律は superpowers の test-driven-development・systematic-debugging・verification-before-completion。
- 設計と実装は、今の一片の FR・受け入れシナリオに要る分だけにする（YAGNI。superpowers の writing-plans の「DRY. YAGNI.」と同じ）。先の一片のための仕組み・設定・抽象化を先回りして作らない。
  テストはこれに含めない。`.claude/rules/testing.md` §9 の下限と技法のケースは、簡単にするために削らない。

## 3. 振り返り（一片ごと）

- 一片の PR がマージされたら、次の一片に進む前に、Allure の `@AC` の結果と `quickstart.md` の手順で動くものを確かめ、
  地図（サブ Issue）の見直し（並び替え・追加・クローズ・分割）を人に提案する。
- 後から変えると高くつく判断が変わったら、設計文書に追記するか新しい設計文書を書き、エピックの Issue を更新する。
