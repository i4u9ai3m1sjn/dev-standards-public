# preset: project-rules

Spec Kit のコマンドに dev-standards の規則を追記する preset。`bootstrap/bootstrap.sh` が各リポジトリで `specify preset add --dev` する。

| 追記先 | 内容 |
|---|---|
| speckit.plan | Project Structure のテストを `tests/l0`〜`l4` で書き、「テストのレベル」の表（機能・レベル・依存・技法・manual・ワークフロー）を足す。何をどこまでテストするかは testing.md §9 |
| speckit.tasks | テストタスクに置き場所 `tests/l<N>/` を書く。受け入れシナリオ番号（US<n>/AC<m>）と `@AC` を E2E テストタスクに付け |
| speckit.converge | `tools/fr_trace.py` を実行し、テストの無い FR・AC と、存在しない FR・AC を指すテストのタグも Findings に入れる（testing.md §8） |

変更したら `preset.yml` の `version` を上げ、各リポジトリで `bootstrap.sh --update` を実行する。
