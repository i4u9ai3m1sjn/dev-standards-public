# dev-standards

複数の製品リポジトリで共通に使う、開発ルール・雛形・スクリプト。
前提にする外部のものは **Spec Kit**（版は `speckit/VERSION`）と **superpowers** だけです。

## 中身

| パス | 役割 | 届き方 |
|---|---|---|
| `CLAUDE.md`、`.claude/rules/` | 共通ルール（テストの書き方、コミット・PR の書き方など） | claude.ai のプロジェクトにこのリポジトリを紐付けると、全スレッドに読み込まれる |
| `setup/setup.sh` | クラウド環境の準備（Spec Kit CLI、`/speckit-*` スキル、Allure CLI の取得） | Project settings の Setup script に中身を貼る |
| `bootstrap/bootstrap.sh` | 製品リポジトリに一式を入れる（1回。`--update` で入れ直し） | スレッドで実行して、製品リポジトリに PR |
| `speckit/presets/project-rules/` | Spec Kit への追記（plan にテストのレベル、tasks に `US<n>/AC<m>` と `@AC`、converge に FR・受け入れシナリオごとのテストの有無） | setup.sh（スキル）と bootstrap.sh（`.specify/`）が当てる |
| `templates/` | bootstrap.sh がコピーする雛形（`templates/tools/fr_trace.py` は FR・受け入れシナリオごとのテストの有無の確認。testing.md §8。`templates/tools/mutation_gate.py` は変更したコードのミューテーションの生き残りの確認。testing.md §10） | — |
| `bootstrap/selftest.sh` | 試験用リポジトリに bootstrap.sh を流し、雛形と pytest の補助が決まりどおり動くかを確かめる | CI（`ci.yml`）と手元 |

## プロジェクトへの入れ方（最初に1回）

1. Project settings > Environment > Repositories：`dev-standards` と製品リポジトリを紐付ける。
2. Project settings > Environment > Setup script：`setup/setup.sh` の中身を貼る。
3. Project settings > Plugins：superpowers を入れる。
4. （画面のある E2E があるなら）ネットワーク許可に `cdn.playwright.dev` を足す。無いと Playwright のブラウザを取ってこられない（2026-10-31 確認）。
5. 新しいスレッドで、`/speckit-specify` などのスキルと共通ルールが見えるかを確かめる。

## 製品リポジトリを足すとき

スレッドで「このリポジトリに dev-standards を入れて」と頼む。Claude が次を実行して PR にします。

```bash
bash /home/user/dev-standards/bootstrap/bootstrap.sh <製品リポジトリのパス>
```

最後に表示される「残りの手順」（テストの依存・実行オプション・既存 CI への手順追加）も同じ PR で行います。

## 変えるとき

| 変えるもの | 手順 | 効き始め |
|---|---|---|
| 共通ルール | PR → マージ | 次に始まるスレッドから |
| 雛形・bootstrap.sh | PR → マージ → タグ | 新しいリポジトリから。既存は必要なときに `bootstrap.sh --update` |
| Spec Kit の版・preset | `speckit/VERSION`・preset を変える → `bash setup/build.sh` → PR → マージ → タグ → Setup script を貼り直す → 各リポジトリで `--update` | Setup script を変えた後の新しいスレッドから |

`setup/setup.sh` は `setup/build.sh` が作るファイルです。直接は編集せず `setup/setup.template.sh` を直します（CI が食い違いを検出します）。

## 公開リポジトリ

このリポジトリは非公開のまま、中身だけを公開リポジトリ（Variables の `PUBLIC_REPO`）に出す。変更の履歴は出さない。
タグ `v*` を push すると `publish-public` ワークフローが、そのタグの中身を1コミットにして公開側の `main` を force push で置き換える
（Actions の画面から手動実行もできる。選んだタグかブランチの中身を出す）。出さないファイルは `.gitattributes` の `export-ignore`（今は `.github/`）。

最初に1回だけ用意する：

1. 公開リポジトリを空で作る（README などを付けない）。
2. 手元で鍵を作る：`ssh-keygen -t ed25519 -N '' -C publish-public -f publish_key`
3. 公開リポジトリの Settings > Deploy keys に `publish_key.pub` を足し、**Allow write access** にチェックする。
4. このリポジトリの Settings > Secrets and variables > Actions に、Secret `PUBLIC_DEPLOY_KEY`（`publish_key` の中身）と
   Variable `PUBLIC_REPO`（`<owner>/<公開リポジトリ名>`）を登録する。登録したら手元の `publish_key`・`publish_key.pub` は消す。
5. 最初の公開は、このワークフローが入った後の `main` を手動実行で出すか、次のタグで出す（ワークフローの無い古いタグは選べない）。

## 未確認のこと（試しながら直す）
- `~/.claude/skills/` に入れた Spec Kit のスキルが、製品リポジトリの `.specify/` を使って analyze・converge まで動くか（specify→plan→tasks は 2026-10-31 に確認済み。実装は `/speckit-implement` ではなく flow.md のとおり writing-plans と subagent-driven-development で行う）。
- CI で保存した Allure の1ファイルを、ダウンロードしてそのまま開けるか（手元の `file://` では動画まで再生できた）。
