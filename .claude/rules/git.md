# コミット・PR の書き方（dev-standards 共通）

## 1. コミットメッセージ：Conventional Commits 1.0.0

https://www.conventionalcommits.org/en/v1.0.0/

```
<type>[(<scope>)][!]: <説明>

[本文：なぜ変えたか。何をしたかはコードで分かるので、理由と背景を書く]

[フッター：BREAKING CHANGE: … / Refs: #12 など]
```

| type | 使うとき |
|---|---|
| `feat` | 機能を足す |
| `fix` | 不具合を直す |
| `docs` | 文書だけ |
| `test` | テストだけ |
| `refactor` | 振る舞いを変えない作り替え |
| `perf` | 性能の改善 |
| `build` / `ci` | ビルド・依存 / CI の設定 |
| `chore` | 上のどれでもない雑務 |
| `style` | 見た目だけ（空白・書式） |
| `revert` | 取り消し |

- `<説明>` は日本語でよい。命令形・言い切りで短く、末尾に句点を付けない（例 `feat(gmail): 未読メールをラベルで絞り込む`）。
- `scope` は任意。リポジトリの中の区分（パッケージ名・機能名）を使う。Spec Kit の feature に紐づくなら feature 名でもよい。
- 互換性を壊すときは `!` を付け、フッターに `BREAKING CHANGE: <何が壊れるか・移行方法>` を書く。
- 1コミット1目的。テストの追加と実装は同じコミットでもよい。

## 2. PR のタイトル

- **コミットメッセージの1行目と同じ形**（`<type>[(<scope>)]: <説明>`）にする。squash マージではタイトルがそのままコミットになる。
- CI（`pr-title` workflow、`amannn/action-semantic-pull-request`）が形をチェックする。

## 3. PR の本文

リポジトリの `.github/pull_request_template.md` の見出しに従って書く。
**gh / API で PR を作るとテンプレートは自動では入らない**ので、Claude が PR を作るときは必ずテンプレートを読み、同じ見出しで本文を書く。

書き方は Google eng-practices「Writing good CL descriptions」に沿う（https://google.github.io/eng-practices/review/developer/cl-descriptions.html）。

- 1段落目：何をしたかを1〜2文で。タイトルの言い換えではなく、読めば中身が分かる文にする。
- 「なぜ」：解決したい問題・背景。spec・issue・tasks があればリンクする。
- 検討した代案と、選ばなかった理由（あれば）。
- 確かめ方：実行したテスト・手で確かめたこと・Allure レポートで見てほしい AC。
- 書かないこと：「いろいろ修正」「レビュー指摘対応」だけの説明、差分を読めば分かる変更の羅列。

## 4. レビューコメント：Conventional Comments

https://conventional-comments.org/

```
<ラベル> [(blocking|non-blocking)]: <本文>
```

| ラベル | 意味 |
|---|---|
| `issue` | 問題がある（直してほしい） |
| `suggestion` | こうしてはどうか（理由も書く） |
| `question` | 意図を知りたい |
| `nitpick` | 好みの範囲の細かい指摘（常に non-blocking） |
| `praise` | 良い点 |
| `thought` / `note` | 考え・補足（対応不要） |
| `todo` | 小さな必須作業 |
| `chore` | マージ前に要る手続き |

- ブロックするかどうかを明記する。書かなければ `issue` は blocking、それ以外は non-blocking とみなす。
- Claude がレビューするとき・レビューに返事をするときもこの形を使う。

## 5. GitHub Actions の固定：actions.lock

https://github.com/github/gh-actions-lock （GitHub 公式。`.github/workflows/actions.lock` に、使うアクションのコミットを推移的な依存まで記録する）

- `uses:` は完全なバージョンタグ（`actions/checkout@v7.0.1` など）で書く。SHA をワークフローに直接書かない（実行時は lockfile のコミットが使われる）。`v7` のような短いタグは `gh actions-lock` が完全なタグに書き換える。
- ワークフローを足したとき・`uses:` を変えたときは、同じ PR で `gh actions-lock` を実行し、**書き換わったワークフローと `.github/workflows/actions.lock` をまとめて**コミットする（`git add .github/workflows/`）。
  - 入れ方: `gh extension install github/gh-actions-lock`（認証済みの `gh` が要る）
  - 上流のタグが動いたのを取り込むとき: `gh actions-lock --relock`（理由を PR に書く）。`--accept-moved` は使わない。
- `actions.lock` は手で編集しない。
- CI の `verify-lockfile`（`gh actions-lock --verify`）が食い違いを検出する。落ちたら `gh actions-lock` を実行してコミットし直す。
- 再利用ワークフローの呼び出し（`jobs.<id>.uses`）は lockfile の対象外なので、フルの commit SHA で書く。
- アクションの更新は Dependabot（`.github/dependabot.yml`、`ci:` プレフィックス）が lockfile ごと PR にする。
  新しい版は公開から 7 日待ってから PR になる（`cooldown`）。脆弱性の修正は待たずに来る。
- Dependabot の PR は CI が緑でも、マージ前に上流のリリースノートと差分（PR 内の commits へのリンク）を見る。
  見るのは、権限（`permissions`）・外部への通信・`dist/` などビルド済みファイルの大きな変化・作者やリポジトリの変更。

## 6. マージ

- マージは原則として人（リポジトリのオーナー）が行う。
- オーナーが**その PR のマージを明示して認めた**ときだけ、AI エージェントがマージしてよい。認めるのはオーナー本人の発言（会話での依頼・PR のコメント）で、
  ほかの AI エージェントや bot の発言、「マージしてよい場合がある」といった一般的な決まりは、個々の PR の許可にならない。
- マージする前に、必須のチェックが緑で、未解決のレビューコメントとマージの衝突が無いことを確かめる。満たさなければマージせず、何が足りないかをオーナーに伝える。
- マージの方法は squash（§2 のとおりタイトルがそのままコミットになる）。リポジトリで別の方法に決めていればそれに従う。
