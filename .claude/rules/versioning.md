# 版の付け方（dev-standards 共通）

目的：利用者が版の番号と CHANGELOG を見れば、何が変わり、上げて大丈夫かが分かるようにする。
独自の方式は作らず、下の外部の仕様に沿う（出典は末尾）。

## 1. 版の番号：Semantic Versioning 2.0.0

- `MAJOR.MINOR.PATCH`。互換性を壊す → MAJOR、後方互換の機能追加 → MINOR、後方互換の不具合修正 → PATCH（SemVer §6〜8）。
- タグは `v` を付ける（`v1.2.3`）。SemVer の版はタグ名の `v` を除いた `1.2.3`（SemVer の FAQ）。
- 出した版の中身は変えない。直すなら新しい版で出す（§3）。間違えて互換性を壊す変更を MINOR・PATCH で出したら、互換性を戻す PATCH を出す（FAQ）。
- `0.y.z` は初期開発で、何が変わってもよい（§4）。それでも互換性を壊す変更は CHANGELOG に必ず書く（§2）。
- 1.0.0 にするときに、公開 API（利用者が頼ってよい面）を README などに書く（§1・§5）。目安は SemVer の FAQ（本番で使われている・利用者が頼る安定した API がある・後方互換をかなり気にしている）。
- 何かを非推奨にしたら MINOR を上げ、消すのは次の MAJOR から。その間に非推奨を含む MINOR を少なくとも1回出す（§7 と FAQ）。
- 上げ方はコミットの type から決まる：`fix` → PATCH、`feat` → MINOR、`!` か `BREAKING CHANGE:` → MAJOR（Conventional Commits。`.claude/rules/git.md` §1）。

例外：出す時期が外の都合で決まるもの（サービス・サポート期間で区切るもの・利用者が技術者でないもの）は CalVer（例 `YYYY.0M.MICRO`）を選んでよい。
選んだら README に方式を書き、互換性を壊す変更は CHANGELOG と、時間で決めた非推奨の期間で伝える（CalVer の「What about breaking changes?」）。

## 2. CHANGELOG：Keep a Changelog 1.1.0

- リポジトリ直下の `CHANGELOG.md`。冒頭に「Keep a Changelog に沿い、Semantic Versioning に従う」と書く。
- 先頭に `## [Unreleased]`。変更を入れる PR で、同じ PR のうちに書き足す。リリースのときに版の節へ移す（§4）。
- 版の見出しは `## [1.2.3] - 2026-11-15`（日付は ISO 8601）。新しい版が上。版ごとの比較のリンク（Keep a Changelog の例にある末尾のリンク）は任意で、公開先に出したくない URL を含むなら置かない。
- 版の中は種類ごとにまとめる：`Added`・`Changed`・`Deprecated`・`Removed`・`Fixed`・`Security`。
- 人のために書く。コミットログを貼らない（コミットはソースの変化の記録で、CHANGELOG は利用者に伝える差）。
- 他を省いても、**非推奨・削除・互換性を壊す変更と、利用者がする移行の手順**は必ず書く。

## 3. 版の表記をそろえる

- 版の正本は1か所にする（PyPA「Single-sourcing the Project Version」）。正本はタグか、版だけを書いたファイル（`VERSION`・`pyproject.toml` など、言語の決まりに従う）。
- 他のファイルに版の写しが要るときは、手で書き換えず、道具に書き換えさせる。既定は release-please を**版だけ**に使う形（CHANGELOG は §2 のとおり人が書くので `skip-changelog: true`）。
  - 正本：release-please の manifest（`.release-please-manifest.json`）と、`version-file` などその言語の版のファイル。
  - 写し：`extra-files` に挙げ、写しの行に `x-release-please-version` を書く（Markdown なら `<!-- x-release-please-version -->`、YAML・シェルなら `# x-release-please-version`）。
  - 0.x の間は `bump-minor-pre-major: true`（互換性を壊す変更で MINOR を上げる。1.0.0 にはしない）。
- 道具を入れないときは、写しと正本が同じかを確かめる自動テストを置く（PyPA の同じページ）。

## 4. リリースの手順（release-please を使うとき）

1. main に `feat`・`fix` などが入ると、release-please がリリース PR（版の写しを書き換える PR）を開き、次の版を示す。
2. 出すと決めたら、ふつうの PR で CHANGELOG の `[Unreleased]` をその版の節（`## [X.Y.Z] - <マージする日>`）へ移し、マージする。
3. リリース PR をマージする。release-please がタグ `vX.Y.Z` と GitHub Release を作る。マージは `.claude/rules/git.md` §6（原則は人）。

- release-please が既定の `GITHUB_TOKEN` で作ったタグ・PR では、他のワークフローは動かない（release-please-action の README）。タグで動かしたいジョブは、release-please のワークフローの中で `release_created` を見て呼ぶ。

## 5. 部品が複数あるとき

- 1つの単位で一緒に配る部品は、同じ版にする（fixed。OpenTelemetry は1つの部品の中を「1つのパッケージとみなして同じ版」にしている）。
- 別々に配り、別々に使われる部品は、別々の版にしてよい（independent）。
- 仕様（ドキュメント）と、それを実装したものの版は別でよい（OpenTelemetry：実装の版は、実装している仕様の版と独立）。どの仕様の版を実装したかは CHANGELOG か README に書く。

## 6. ドキュメント

- ドキュメントはソースと同じリポジトリに置き、コードを変えた同じ PR で直す（Google の docguide「Update Docs with Code」）。ドキュメントの版は、ソースと同じタグで付く。
- 版ごとのドキュメントサイトは、利用者が古い版を使い続け、版の間でドキュメントが大きく変わるときだけ作る（Docusaurus「Versioning」：多くの場合は要らない）。

出典：
- Semantic Versioning 2.0.0 https://semver.org/spec/v2.0.0.html
- Keep a Changelog 1.1.0 https://keepachangelog.com/en/1.1.0/
- Calendar Versioning https://calver.org/
- Conventional Commits 1.0.0 https://www.conventionalcommits.org/en/v1.0.0/
- PyPA「Single-sourcing the Project Version」 https://packaging.python.org/en/latest/discussions/single-source-version/
- OpenTelemetry「Versioning and stability」 https://opentelemetry.io/docs/specs/otel/versioning-and-stability/
- release-please https://github.com/googleapis/release-please （`docs/manifest-releaser.md`・`docs/customizing.md`）、release-please-action https://github.com/googleapis/release-please-action
- Google docguide「Best Practices」 https://google.github.io/styleguide/docguide/best_practices.html
- Docusaurus「Versioning」 https://docusaurus.io/docs/versioning
