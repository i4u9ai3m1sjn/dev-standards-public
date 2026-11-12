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
