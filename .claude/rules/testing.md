# テストの書き方（dev-standards 共通）

目的：CI が緑になった中身を、人が Allure レポートで素早く確かめられるようにする。
「何を変えたか」「何を確かめるか」は設計（spec・plan・tasks）の段階で合意済みなので、
PR では主に **受け入れシナリオ（AC）の E2E の証跡（動画・スクショ・出力）** を見る。

## 1. 名前と番号

| 対象 | 書き方 | 例 |
|---|---|---|
| すべての要件テスト | 名前に `[<featureディレクトリ名>/FR-###]` を入れる | `[001-login/FR-004] 誤ったパスワードで残り回数を表示する` |
| 受け入れシナリオの E2E | さらに `US<n>/AC<m>` を入れ、タグ `@AC` を付ける | `[001-login/FR-005] US1/AC2 ログイン後にダッシュボードへ遷移する` |

- `US<n>/AC<m>` は spec.md の User Story n の Acceptance Scenarios を上から数えた m 番目（tasks の preset と同じ数え方）。
- 1つのテストに FR が複数あるときは `[001-login/FR-004][001-login/FR-006]` と並べる。
- 既存リポジトリに独自の ID（例 `[REQ-020][TC-020-11]`）があるときは、それを残したまま上の形を足してよい。

## 2. ステップ

- 操作と確認をステップに分ける。確認のステップ名は **`期待: ` で始める**（例 `期待: /dashboard に移り「ようこそ」が出る`）。
- ステップ名は日本語でよい。spec の受け入れシナリオの Then をそのまま写すと読み合わせが速い。

## 3. テストレベルごとの証跡

テストが「何を確かめるか」は、ISTQB Foundation Level シラバス v4.0 の 2.2.1 のテストレベル（用語は JSTQB の訳）で呼ぶ。
§6 の L0〜L4（何に依存し、いつ動くか）とは別の軸で、1つのテストに両方を付ける（例：ローカルの DB を使うコンポーネント統合テストは L2）。
どこまで書くかは §9。

| テストレベル（ISTQB） | 何を確かめるか | 何を残すか |
|---|---|---|
| コンポーネントテスト | 1つのコンポーネント（関数・クラス・モジュール）を単独で | 名前とステップだけでよい（添付は不要） |
| コンポーネント統合テスト | 自分のシステムの中のコンポーネント同士（自分の DB・ファイルを含む）のインターフェースと相互作用 | リクエスト・応答・保存先（DB・ファイル）の中身を添付する |
| システム統合テスト | 外部のシステム・サービス（Slack・S3・他チームの API など）とのインターフェース | 送ったもの・受け取ったもの・外部サービスから読み戻した結果を添付する |
| システムテスト | システム全体の振る舞い（機能・非機能） | 下の E2E の証跡 |
| 受け入れテスト | 利用者の観点で使えるか。このルールでは受け入れシナリオ（§1 の `@AC`） | 下の E2E の証跡（常に残す） |

システムテストと受け入れテストは、利用者の入口（画面・CLI・API）から端から端まで通して行う。このルールではこの行い方を **E2E** と呼ぶ（テストレベルではない）。

| E2E の入口 | 何を残すか |
|---|---|
| 画面あり | Playwright（TypeScript）で書く。動画・スクショ・トレースは設定で自動添付される（`@AC` は常に、それ以外は失敗時だけ） |
| 画面なし（CLI・API・バッチ） | 実行したコマンド、終了コード、標準出力、外部サービスから読み戻した結果を添付する |

- 秘密情報（トークン・パスワード・Webhook URL など）は添付しない。Python は `attach_json` が秘密らしいキーを `***` にする。
- 画面のある E2E は Playwright（TypeScript）に揃える。製品のコードが別の言語でも、E2E だけ TypeScript で書く。

## 4. 出力先（変えない）

| ファイル | 用途 |
|---|---|
| `out/allure-results/` | Allure の材料（人が見るレポートは CI が `allure generate` で1ファイルにする） |
| `out/junit*.xml` | トレース用（FR の網羅の確認に使う） |

`out/` はコミットしない（`.gitignore`）。レポートの設定は `allurerc.mjs`（`name` だけリポジトリごとに変える）。

## 5. 言語ごとの書き方

### TypeScript（Playwright：E2E）
```ts
test('[001-login/FR-005] US1/AC2 ログイン後にダッシュボードへ遷移する', { tag: '@AC' }, async ({ page }) => {
  await test.step('正しいユーザー名とパスワードを入力して送信', async () => { /* … */ });
  await test.step('期待: /dashboard に移り「ようこそ」が出る', async () => {
    await expect(page).toHaveURL(/dashboard/);
  });
});
```

### TypeScript（Vitest：コンポーネント・コンポーネント統合・システム統合）
```ts
import * as allure from 'allure-js-commons';
it('[001-login/FR-002] コンポーネント統合: POST /login が 200 と session を返す', async () => {
  const res = await fetch(`${base}/login`, { method: 'POST', body });
  await allure.attachment('response', JSON.stringify(await res.clone().json(), null, 2), 'application/json');
  await allure.step('期待: 200 が返る', () => expect(res.status).toBe(200));
});
```
`expect(...)` は allure-vitest が自動でステップとして記録する。

### Python（pytest）
- `tests/allure_support.py`（bootstrap.sh が置く）が、**docstring の1行目を表示名にし、JUnit XML の `title` プロパティにも書く**。
  pytest の関数名には `[ ]` や日本語を入れにくいので、名前と番号は docstring の1行目に書く。
- `@AC` は `@pytest.mark.ac` で付ける（allure-pytest がタグにする）。

```python
# tests/l3/test_slack_notify.py（テスト用の実 Slack チャンネルに投稿するので L3。§6）
import allure
import pytest
from tests.allure_support import attach_command, attach_json

@pytest.mark.ac
def test_notify_posts_to_slack(run_cli, slack):
    """[003-notify/FR-002] US1/AC1 slack notify でチャンネルに投稿される"""
    with allure.step("slack notify を実行する"):
        r = run_cli(["claude-handy", "slack", "notify", "--text", "hello"])
        attach_command(r.args, r.returncode, r.stdout, r.stderr)
    with allure.step("期待: チャンネルの最新メッセージが hello"):
        msg = slack.latest()
        attach_json("Slack から読み戻したメッセージ", msg)
        assert msg["text"] == "hello"
```

### 他の言語
Allure の公式アダプタ（Java/Kotlin・.NET・Go・PHP・Ruby・Rust・Dart など）を使い、結果を `out/allure-results/` に、
JUnit XML を `out/junit*.xml` に出す。名前・ステップ・添付の規則は上と同じ。

## 6. 依存レベル（L0〜L4）と実行タイミング

テストが「何に依存しているか」で L0〜L4 のどれか1つを決め、それで「いつ動くか」が決まる。
レベルは **Microsoft の DevOps のテスト分類（L0〜L4）をそのまま使い**、`manual` は **Bazel の `manual` タグと同じ意味**にする。独自の区分は作らない。

- https://learn.microsoft.com/en-us/devops/develop/shift-left-make-testing-fast-reliable （「DevOps test taxonomy」と「Unit test guidelines」「Functional test guidelines」）
- https://bazel.build/reference/be/common-definitions （共通属性 `tags` の `manual`）

### 6.1 レベル

| レベル | Microsoft の定義 | このルールでの例 |
|---|---|---|
| **L0** | 単体テスト。テスト対象のコードだけに依存する、速いメモリ内のテスト（1件の平均 60ms 未満） | 純粋な関数、API をモックした CLI、moto の `mock_aws`（同じプロセス内のフェイク） |
| **L1** | 単体テスト。テスト対象のコードだけに依存するが、L0 ほど軽くないもの（1件の平均 400ms 未満、どれも 2 秒以内） | 一時ファイル（pytest の `tmp_path`）を使う、CLI をサブプロセスで起動する（外部はモック） |
| **L2** | 機能テスト。テスト対象に加えて SQL やファイルシステムなどの依存を使う。**分離**が要（テストが環境を完全に握り、どの順で流しても同じ結果） | テストが立ち上げるローカルの DB・エミュレータ・moto のサーバーモード、`webServer` で起動した画面への Playwright |
| **L3** | テスト用にデプロイしたサービスに対する機能テスト。デプロイが要るが、主な依存はスタブでもよい | テスト環境にデプロイした自分のサービス。**外部サービスのテスト用の環境（テスト用チャンネル・バケット・アカウント）を使うテストもここ**（下の注） |
| **L4** | 本番に対する、限られた結合テスト。製品全体のデプロイが要る | 本番デプロイ後のスモークテスト |

注：実 Slack・実 S3・実 Google などに CI から繋ぐテストは、Microsoft が L2 の説明で「外部の認証基盤などに繋ぐのは分離の原則に反する」としているので
L2 には入れず、L3（テスト用に用意された環境に対するテスト）に入れる。秘密情報が要るのも L3 から。

- 1つのテストに付くレベルは1つだけ。迷ったら依存の重い方にする。
- テストレベル（§3）とは独立している（例：API をモックした CLI のシステムテストは L0 か L1、実 API のテスト用環境に繋ぐ受け入れテストは L3）。L0・L1 の説明の「単体テスト」は Microsoft の言葉で、§3 のコンポーネントテストに限らない。
- Microsoft の「できるだけ低いレベルで書く」に従い、軽いレベルで同じことが確かめられるならそちらで書く。

### 6.2 `manual`（例外フラグ）

既定の実行から外し、**明示したときだけ動かす**テストに付ける。レベルとは別に付ける（例：L3 かつ manual）。
Bazel の `manual` と同じ意味（ワイルドカードでの実行から外れ、名指ししたときだけ動く。CI で動かさないという意味ではない）。
付ける理由の例：

- 人がいないと動かせない（OTP・デバイス認証の入力、目視の確認）
- 重い・長い（例：30日分をなめるフルスキャン）
- 1回ごとに費用や外部への影響が大きい（有料 API を大量に呼ぶ、実チャンネルに多く投稿する）

決まり：

- 既定では実行しない。環境変数 `RUN_MANUAL=1` のときだけ実行する（専用のワークフローや手元で、明示して流す）。
- manual で既定から外すのは、§7 の「skip して緑にしない」には当たらない。その代わり、**付けた理由と、誰が・いつ・どのワークフローで流すか**を
  各リポジトリの `docs/testing/strategy.md` に必ず書く。
- 落ちているテストを黙らせるために manual にしない（それは §7 の skip と同じ）。

### 6.3 置き場所と名前

```
tests/
  l0/  test_<機能>_<操作>.py   （Node は *.test.ts）
  l1/  …                       （Node の画面 E2E は *.spec.ts）
  l2/  …
  l3/  …
  l4/  …
```

- **ディレクトリ ＝ レベル、ファイル名 ＝ 機能**。同じ機能のテストが l0 と l3 に分かれても、ファイル名で対応が追える。
- 1つのファイルにレベルを混ぜない。混ざったら分ける。
- Python は `tests/levels.py`（bootstrap.sh が置く）が置き場所から marker `l0`〜`l4` を付け、`@pytest.mark.manual` を既定で外す。
  移行が終わったら pytest に `--require-level` を付け、置き場所の外のテストを収集エラーにする（`-m "l0 or l1 or l2"` で黙って外れるのを防ぐ）。
- Node は置き場所で選ぶ（`vitest run tests/l0 tests/l1 tests/l2`、`playwright test tests/l2`）。manual は名前に `@manual` を入れ、
  Playwright は設定で既定から外し、Vitest は `it.skipIf(process.env.RUN_MANUAL !== '1')` にする。

### 6.4 いつ動かすか（既定）

| レベル | PR | main への push | 定期 | その他 |
|---|---|---|---|---|
| L0・L1・L2 | すべて | すべて | — | 手元でもいつでも |
| L3 | 変更した機能に関係するものだけ（ワークフローの `paths` で絞る） | すべて | 週1回すべて | 手動実行（`workflow_dispatch`）もできるようにする |
| L4 | — | — | — | 本番デプロイの後 |
| manual | — | — | — | `strategy.md` に書いたタイミングで人が流す |
| ミューテーションテスト（§10） | 変更したコードだけ | 変更したコードだけ | 週1回すべて | 手動実行（`workflow_dispatch`）ですべて |

- Microsoft は「どこで何を流すかは組織ごとに決めてよい」としている（例として、L2 まではコミット前、L3 が落ちたら PR を落とす、L4 が落ちたらデプロイを止める）。
  この共通ルールでは、外部のトークンが切れても関係のない PR が止まらないように、**L3 を PR の必須チェック全体には入れない**。
- L3 を PR で絞るとき、共通のコード（認証・設定・共通モジュールなど、複数の機能が使うもの）を変えた PR では L3 をすべて流す。
  どのパスが共通かは `strategy.md` に書き、ワークフローの `paths` にも入れる。
- Dependabot の PR とフォークからの PR には secrets が渡らないので、L3 のジョブはそれらでは動かさない
  （`if: github.event_name != 'pull_request' || (github.actor != 'dependabot[bot]' && github.event.pull_request.head.repo.full_name == github.repository)`。
  push・定期実行には `pull_request` が無いので、`event_name` の条件を外すと main への push と定期実行でも L3 が動かなくなる）。
  雛形は bootstrap.sh が置く `.github/workflows/test-l3.yml`。
  これは「対象外」の宣言であって §7 の skip ではない。main への push と定期実行で必ず流れる。
- **テストを流すワークフローはすべて**（L0〜L4・manual）Allure（`out/allure-results/`）と JUnit XML を出し、レポートをジョブサマリーにリンクする。
  受け入れシナリオ（`@AC`）の E2E がどのレベルでも、それが動いたワークフローのレポートで証跡を見られる。
  レポートはテストを流すジョブとは別のジョブで作る（テストのジョブが `out/allure-results/` を artifact で渡し、`needs` で続くジョブが受け取る。GitHub 公式の「ジョブ間でデータを渡す」形）。赤くなったジョブの名前で、テストが落ちたのか、レポート作りで落ちたのかが分かるようにするため。`tools/fr_trace.py`（§8）もテストを流さないので別のジョブにする。
- この既定から外すとき（例：L3 を毎 PR で全部流す）は、理由をリポジトリの `docs/testing/strategy.md` に書く。

### 6.5 各リポジトリに書くこと

`docs/testing/strategy.md` に次を書く。共通の定義（この節）は写さない。

- 機能ごとの対応表（機能、置き場所、レベル、manual か、動かすワークフロー）
- 共通のコードとみなすパス（6.4）
- 既定（6.4）から外したところと理由
- manual を付けた理由と、誰が・いつ・どのワークフローで流すか

## 7. しないこと
- テストを skip・削除して緑にしない。skip するときは理由（tasks の番号など）を書く。
- レポートの見た目のためだけに、テストの中身や期待値を変えない。

## 8. FR・受け入れシナリオごとのテストの有無（`tools/fr_trace.py`）

spec.md の FR と受け入れシナリオ（`US<n>/AC<m>`）ごとに、テストが書かれているかを機械的に確かめる。Spec Kit の analyze は「FR にタスクがあるか」、
converge は「コードがあるか」を AI が判断するだけで、テストの有無は見ないため、この道具で補う。bootstrap.sh が `tools/fr_trace.py` を置く（標準ライブラリだけで動く）。

- 読むもの：`specs/*/spec.md` の `**Status**:`・`**FR-###**`・各 User Story の Acceptance Scenarios（§1 と同じ数え方）と、
  `tests/l0`〜`l4` のファイルに書かれた `[<feature>/FR-###]`。同じ行に `US<n>/AC<m>` があれば、その AC のテストとして数える（テスト名は1行に書く）。
  `tests/` 直下の共通ファイルや、置き場所（§6.3）の外のテストは見ない。
- 見るのは「タグを持つテストがあるか」と、そのレベルだけ。テストは流さず、結果（通った・失敗・skip・manual）は見ない。結果は Allure で見る（§7 の skip もそこで見る）。
- CI（test-report.yml）で毎回流し、FR・AC ごとの表をジョブサマリーに出す。**落とすのは次の2つだけ**：
  - spec.md の Status が `Implemented` の feature に、テストの無い FR・AC がある
  - テストのタグが、存在しない feature・FR・AC を指している（打ち間違い）
- Status が `Implemented` でない feature（Draft など）は表に出すだけで落とさない。一片の PR を仕上げるときに Status を `Implemented` にする（flow.md §2）。
- この一片で作れない FR・AC を「対象外」にする印は作らない。spec から外して次の一片に移す（flow.md §2）。
- `/speckit-converge` は preset でこの道具を実行し、テストの無い FR・AC をタスクにする。

## 9. 何をどこまでテストするか

目的は「テストが通った＝ちゃんと動く」と言えるようにすること。テストは減らす対象ではない。
簡単にするのは設計と実装の方（flow.md §2）で、テストのケースを削って簡単にしない。
下の 9.1・9.2 は外部の体系（ISTQB・Fowler）から使い方を借りたもので、各 FR に当てはまるものを選んで使う。
1つ1つのテストは「どんな壊れ方を捕まえるか」を言えるようにする（superpowers の test-driven-development の `writing-good-tests.md`）。
数を絞るためではなく、言えないテストは何を守っているのかレビューで判断できないため。

**下限（これより少なくしない）**

1. 各 FR にテストが1つ以上、各受け入れシナリオに `@AC` の E2E が1つ以上ある（§1・§8。CI が確かめる）。
2. 自分のプロセスの外にある相手（DB・外部 API・キュー・メールなど）とやり取りする FR は、その境界を**実物か、通信越しの代わり（エミュレータ・フェイクのサーバー）に対して**通すテストを1つ以上持つ（L2 以上）。
   同じプロセス内のモックに置き換えただけの L0・L1 では満たさない（9.2）。
3. そのうち相手が**自分で管理していない外部のシステム・サービス**（Slack・S3・決済・他チームの API など）なら、テスト用の実物に通す広い結合テスト（L3）も、やり取りの経路ごとに1つ以上持つ（9.2）。
   相手のテスト用の環境が用意できないときは、plan.md の「テストのレベル」の表にその理由を書き、L2 で代える。

2・3 は CI では確かめない（`tools/fr_trace.py` の表で FR ごとのレベルは見える）。plan.md の表の確認（flow.md §2 の 2）で見る。

### 9.1 ケースの分け方：ISTQB のブラックボックス技法

ISTQB Foundation Level シラバス v4.0 の 4.2 節の技法を使う。FR が下の「使うとき」に当てはまれば、その技法でケースを分ける（1つの FR に複数当てはまれば、どれも使う）。
カバレッジは表の「基本のカバレッジ」以上にする。壊れると影響が大きい FR は「広げるとき」まで上げる。

| 技法 | 使うとき | 基本のカバレッジ（シラバスの用語） | 広げるとき |
|---|---|---|---|
| 同値分割法 | 入力・出力が「同じ扱いになるパーティション」に分かれる（有効な値と無効な値など） | 無効パーティションを含む各パーティションを1回。入力が複数あるときはイーチチョイスカバレッジ | 入力同士の組み合わせで結果が変わるなら、組み合わせ（デシジョンテーブル）にする |
| 境界値分析 | 順序のあるパーティションに上限・下限がある（件数・長さ・金額・日付） | 2値 BVA（境界値と、隣のパーティションの最も近い値） | 3値 BVA（境界値と、その両隣） |
| デシジョンテーブルテスト | 複数の条件の組み合わせで結果が変わる業務ルール | 実行可能な列をすべて1回 | — |
| 状態遷移テスト | 状態を持ち、イベントで状態が変わる（注文・申請・セッション） | 有効遷移カバレッジ（0スイッチカバレッジ）：有効な遷移をすべて1回 | 全遷移カバレッジ（無効な遷移が拒まれることも確かめる） |

- 使った技法とカバレッジは plan.md の「テストのレベル」の表の「技法」の列に書く（当てはまる技法が無い FR は空欄で、下限の 1 を満たせばよい）。
- 受け入れシナリオ（Given/When/Then）を E2E にするのは、同じシラバスのコラボレーションベースのアプローチ（受け入れ基準・ATDD）に当たる。§1 の `@AC` がそれ。

### 9.2 結合の範囲：狭い結合と広い結合

| 呼び方（Martin Fowler「IntegrationTest」） | 何を確かめるか | 相手 | 依存レベル（§6） |
|---|---|---|---|
| 狭い結合テスト | 自分のコードのうち、相手とやり取りする部分だけ | テストダブル（同じプロセス内か、通信越しのフェイクのサーバー・エミュレータ） | L0・L1（同じプロセス内）、L2（通信越し） |
| 広い結合テスト | 相手を実際に動かした経路全体 | 実物（テスト用の環境） | L3 |

- 下限の 2 は、狭い結合テストのうち**通信越し（L2）か実物（L3）**のものを1つ求める。同じプロセス内のダブルだけでは、相手との通信の形（シリアライズ・接続・エラー応答）を通らないため。
- 下限の 3 は、外部のシステム・サービスに広い結合テストを求める。ダブルは自分が思っている相手の振る舞いでしかなく、認証・権限・制限・実際の応答の形の食い違いは実物でしか見つからないため（ISTQB のシステム統合テストも、できれば運用環境に近い環境で行うとしている）。
- ケースの細かい分け方（9.1）は速い狭い結合テスト（L0〜L2）で網羅し、広い結合テスト（L3）は実物との経路が通ることを確かめる（Fowler も、狭い結合を中心にし、実物との通しのテストは経路を限って行うとしている）。L3 は PR では変更した機能の分しか流れないので（§6.4）、ケースを L3 だけに置かない。
- ダブルが相手に忠実かどうかは、Fowler は契約テストで確かめるとしている。相手が自分たちで変えられる API（社内の別サービスなど）で、L3 を頻繁に流せないときは契約テストも書く。
- 狭い・広いは結合の範囲の呼び分けで、§3 のコンポーネント統合テストとシステム統合テストのどちらにも使う。自分の DB とやり取りするのはコンポーネント統合テスト（下限の 2）、外部のシステム・サービスとやり取りするのはシステム統合テスト（下限の 2・3）。
- 依存レベル L0〜L4 は「何に依存し、いつ流すか」の軸で、この節は「何を確かめるか」の軸。どちらかで他方を置き換えない。

出典：
- ISTQB Foundation Level シラバス v4.0（2.2.1 テストレベル、4.2 ブラックボックステスト技法、4.5 コラボレーションベースのテストアプローチ）。日本語版（JSTQB、Version 2023V4.0.J02）は https://www.jstqb.jp/syllabus/ から
- Martin Fowler「IntegrationTest」https://martinfowler.com/bliki/IntegrationTest.html

## 10. ミューテーションテスト

目的：§9 の「1つ1つのテストは、どんな壊れ方を捕まえるかを言える」を、道具で確かめる。本番のコードを小さく壊したもの（ミュータント）を作ってテストを流し、
どのテストも落ちなければ（生き残り）、その壊れ方を捕まえるテストが無い。superpowers の test-driven-development（`writing-good-tests.md`）の
「The Mutation Check」を、頭の中でなく道具で行うもの。§8 の `fr_trace.py` は「テストがあるか」、ここは「テストが壊れ方を捕まえるか」を見る。

### 10.1 道具と、殺す側のテスト

| 言語 | 道具 | 設定（bootstrap.sh が置く・残りの手順に出す） |
|---|---|---|
| TypeScript・JavaScript | StrykerJS ＋ `@stryker-mutator/vitest-runner` | `stryker.config.json`（`mutate` を製品のコードの置き場所に合わせる）、`vitest.mutation.config.ts` |
| Python | mutmut 3 | `pyproject.toml` の `[tool.mutmut]`（`source_paths`、`pytest_add_cli_args = ["-m", "not l3 and not l4"]`）。pytest の `testpaths = ["tests"]`（`mutants/` を拾わないため） |
| 他の言語 | 公式の道具（Java は PIT、C# は Stryker.NET など） | 判定・証跡は下と同じにする |

- 殺す側のテストは **L0〜L2**（test-report.yml と同じ）。L2 は分離されていて何度流しても同じ結果になる（§6.1）。L0・L1 だけにすると、L2 でしか確かめていない境界のミュータントが生き残りに見える。
- 画面の E2E（Playwright）と L3・L4 は使わない。ミュータントの数だけ流すことになり、重いうえに外部や本番を叩く。

### 10.2 いつ流すか

| いつ | 何を | やり方 |
|---|---|---|
| 実装中（flow.md §2 の 3） | 変えたファイル | 手元で流し、生き残りにテストを足してから PR にする |
| PR・main への push | 変更したコード | 前回の結果をキャッシュから戻して、変わった所だけ流す（StrykerJS の `incremental`、mutmut は `mutants/` を戻すと変わった関数だけやり直す） |
| 週1回・手動実行 | すべて | 前回の結果を使わずやり直す。差分実行は依存・設定・環境の変化を検出しないため（StrykerJS の incremental の Limitations） |

雛形は bootstrap.sh が置く `.github/workflows/mutation.yml`（週1回すべて流すので test-report.yml とは分ける）。

### 10.3 判定

- **変更したコードに生き残りが1つでもあれば落とす**。変更したコードは `git diff <比較元>...HEAD` で足した・変えた行。StrykerJS はミュータントの行で、mutmut 3 は関数ごとにミュータントを作るので、変えた行を含む関数で突き合わせる。
  生き残りは、StrykerJS の `Survived`・`NoCoverage`（テストが通らない）・`Pending`、mutmut の `survived`・`no tests`・`not checked`。判定は bootstrap.sh が置く `tools/mutation_gate.py`（標準ライブラリだけで動く）。
- リポジトリ全体のスコア（StrykerJS の `thresholds.break`、PIT の `mutationThreshold` など）では落とさない。変えていないコードのせいで関係のない PR が止まらないようにする（§6.4 で L3 を PR の必須にしないのと同じ）。全体のスコアは週1回の結果で見る。
- 生き残りには、それを殺すテストを足す（§9 の技法で分けたケースの漏れであることが多い）。テストの期待値を弱めたり、テストを消したりして数を合わせない（§7）。
- 等価ミュータント（どう書いても振る舞いが変わらないもの）だけは、**理由付きの除外コメント**で外す。除外は §7 の skip と同じく、理由の無いものを置かず、レビューで見る。
  - StrykerJS：`// Stryker disable next-line <mutator名>: <理由>`（理由はレポートにも出る）
  - mutmut：`# pragma: no mutate` の後ろに理由を書く（例 `# pragma: no mutate  送料は固定で、+1 と -1 は仕様上同じ`）
- 変えたのがテストだけのとき、変えていないコードに出た生き残りは PR では数えない（週1回の全体の結果で見つける）。

### 10.4 証跡

| 何 | 出し先（`out/mutation/`。コミットしない） | 見せ方 |
|---|---|---|
| StrykerJS の HTML レポート | `mutation.html`（1ファイルで開ける） | ワークフローの成果物（`archive: false`）。リンクをジョブサマリーに出す |
| StrykerJS の JSON | `mutation.json`（mutation-testing-report-schema） | `mutation_gate.py` が読む |
| mutmut の生き残りと差分 | `survivors.md`（`mutmut show` の差分つき）、`mutmut-cicd-stats.json`（件数） | ワークフローの成果物。リンクをジョブサマリーに出す |
| 変更したコードの表 | ジョブサマリー | 状態・ファイル・場所・ミュータント・除外の理由と、全体のスコア（参考） |

- Allure には入れない。Allure はテストの結果で、ミュータントは「テストの評価」なので、偽のテストケースを作って載せることになる。成果物を並べて置く。

### 10.5 各リポジトリに書くこと

`docs/testing/strategy.md` に、ミューテーションの対象のパス（`mutate`・`source_paths`）と、対象から外したパスとその理由を書く。

出典：
- StrykerJS の公式ドキュメント（Configuration の `thresholds`・`incremental`・`htmlReporter`・`jsonReporter`、Incremental、Disable mutants）と mutation-testing-elements の「Mutant states and metrics」
- mutmut の README と HISTORY（3.x。`mutmut results`・`show`・`export-cicd-stats`、関数ごとのハッシュによるやり直し、`# pragma: no mutate`）
- 差分のコードだけをレビューで扱うやり方：Petrović ほか「Practical Mutation Testing at Scale: A view from Google」（IEEE Transactions on Software Engineering, 2021）
