#!/bin/bash
# dev-standards: 製品リポジトリに Spec Kit・Allure の雛形を入れる。何度実行しても壊れない（あるファイルは上書きしない）。
#
#   bash bootstrap/bootstrap.sh [--update] [--with-playwright] <製品リポジトリのパス>
#
#   --update           .specify/ を Spec Kit の固定版で入れ直し、preset も当て直す
#   --with-playwright  画面のある E2E 用に playwright.config.ts を置く（Node のリポジトリでは既定で置く）
#
# 依存の追加（pip / npm）やテスト実行コマンドの変更は行わず、最後に「残りの手順」として表示する。
set -euo pipefail

ds="$(cd "$(dirname "$0")/.." && pwd)"
update=0
with_pw=0
target=""
for a in "$@"; do
  case "$a" in
    --update) update=1 ;;
    --with-playwright) with_pw=1 ;;
    -h|--help) sed -n 2,9p "$0"; exit 0 ;;
    *) target="$a" ;;
  esac
done
[[ -n "$target" ]] || { echo "使い方: bash $0 [--update] [--with-playwright] <製品リポジトリのパス>" >&2; exit 2; }
target="$(cd "$target" && pwd)"
version="$(cat "$ds/VERSION")"
speckit_version="$(cat "$ds/speckit/VERSION")"
repo_name="$(basename "$target")"
todo=()
log() { echo "[bootstrap] $*"; }

# 雛形を、無いときだけコピーする
place() {
  local src="$1" dst="$target/$2"
  if [[ -e "$dst" ]]; then
    log "そのまま: $2（既にある）"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log "置いた: $2"
  fi
}

# 言語の判定
lang=""
[[ -f "$target/pyproject.toml" || -f "$target/requirements.txt" || -f "$target/setup.py" ]] && lang="python"
[[ -f "$target/package.json" ]] && lang="${lang:+$lang+}node"
[[ "$lang" == *node* ]] && with_pw=1
log "対象: $target（言語: ${lang:-不明}）"

# 1. Spec Kit
if [[ ! -d "$target/.specify" || $update -eq 1 ]]; then
  if command -v specify >/dev/null 2>&1; then
    have="$(specify --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
    [[ "v$have" == "$speckit_version" ]] || log "注意: specify の版が ${have:-不明} です（固定版は $speckit_version）"
    (cd "$target" && specify init --here --integration claude --script sh --force --ignore-agent-tools)
    log "Spec Kit を入れた（.specify/ と .claude/skills/speckit-*）"
  else
    log "注意: specify がありません。クラウド環境のセットアップスクリプト（setup/setup.sh）を確認してください"
    todo+=("specify ${speckit_version} を入れてから bootstrap.sh を再実行する")
  fi
fi
if [[ -d "$target/.specify" ]] && command -v specify >/dev/null 2>&1; then
  if [[ $update -eq 1 || ! -d "$target/.specify/presets/project-rules" ]]; then
    (cd "$target" && { [[ -d .specify/presets/project-rules ]] && specify preset remove project-rules >/dev/null; true; } \
      && specify preset add --dev "$ds/speckit/presets/project-rules") && log "preset project-rules を当てた"
  else
    log "そのまま: preset project-rules（既に入っている）"
  fi
fi

# 2. Allure の設定
if [[ ! -e "$target/allurerc.mjs" ]]; then
  sed "s/__REPO_NAME__/$repo_name/" "$ds/templates/allurerc.mjs" > "$target/allurerc.mjs"
  log "置いた: allurerc.mjs"
else
  log "そのまま: allurerc.mjs（既にある）"
fi

# 3. 言語ごとの雛形
if [[ "$lang" == *python* ]]; then
  place "$ds/templates/python/allure_support.py" "tests/allure_support.py"
  place "$ds/templates/python/levels.py" "tests/levels.py"
  conftest="$target/tests/conftest.py"
  want=()
  grep -qs "tests.allure_support" "$conftest" || want+=('"tests.allure_support"')
  grep -qs "tests.levels" "$conftest" || want+=('"tests.levels"')
  if [[ ${#want[@]} -gt 0 ]]; then
    plugins="$(printf '%s, ' "${want[@]}")"; plugins="${plugins%, }"
    if grep -qs "^pytest_plugins" "$conftest"; then
      todo+=("tests/conftest.py の pytest_plugins に ${plugins} を足す（既に pytest_plugins があるため自動では書き換えていない）")
    else
      [[ -f "$target/tests/__init__.py" ]] || : > "$target/tests/__init__.py"
      { [[ -s "$conftest" ]] && echo; echo '# dev-standards: Allure の表示名（allure_support）と、置き場所からの依存レベル付け（levels）'; echo "pytest_plugins = [${plugins}]"; } >> "$conftest"
      log "追記: tests/conftest.py（pytest_plugins）"
    fi
  fi
  todo+=("開発用の依存に allure-pytest を足す（例: pyproject.toml の dev に \"allure-pytest>=2.16\"）")
  todo+=("pytest の実行に --alluredir=out/allure-results --junitxml=out/junit.xml を足す（Docker で動かすなら out/ をホストに出す）")
  grep -qs '^\[tool.mutmut\]' "$target/pyproject.toml" \
    || todo+=("pyproject.toml に [tool.mutmut]（source_paths = [\"src/\"]、pytest_add_cli_args = [\"-m\", \"not l3 and not l4\"]）と、[tool.pytest.ini_options] の testpaths = [\"tests\"] を足す（ミューテーションテスト。.claude/rules/testing.md §10）")
fi
if [[ "$lang" == *node* ]]; then
  place "$ds/templates/node/vitest.config.ts" "vitest.config.ts"
  todo+=("npm i -D vitest allure-vitest allure-js-commons")
  # ミューテーションテスト（testing.md §10）
  place "$ds/templates/node/stryker.config.json" "stryker.config.json"
  place "$ds/templates/node/vitest.mutation.config.ts" "vitest.mutation.config.ts"
  todo+=("npm i -D @stryker-mutator/core@10.1.1 @stryker-mutator/vitest-runner@10.1.1（ミューテーションテスト。stryker.config.json の mutate を製品のコードの置き場所に合わせる）")
fi
if [[ $with_pw -eq 1 ]]; then
  place "$ds/templates/node/playwright.config.ts" "playwright.config.ts"
  todo+=("npm i -D @playwright/test@1.64.1 allure-playwright（画面のある E2E 用）")
fi

# 3b. FR・受け入れシナリオごとのテストの有無（testing.md §8。CI の test-report.yml と /speckit-converge が使う）
place "$ds/templates/tools/fr_trace.py" "tools/fr_trace.py"
# 3c. ミューテーションテストの判定（testing.md §10。CI の mutation.yml が使う）
place "$ds/templates/tools/mutation_gate.py" "tools/mutation_gate.py"

# 4. CI（テストのワークフロー。L0〜L2 は test-report.yml、L3 は test-l3.yml。testing.md §6.4）
wf_dir="$target/.github/workflows"
tpl_lang="${lang/+/-}"   # python / node / python-node

# Python の依存の入れ方を、リポジトリにあるファイルから決める（雛形の __PY_INSTALL__）
py_install=""
py_guessed=0
if [[ "$lang" == *python* ]]; then
  if [[ -f "$target/pyproject.toml" ]] && python3 - "$target/pyproject.toml" <<'PY_DEV'
import sys
try:
    import tomllib
except ImportError:
    sys.exit(1)
with open(sys.argv[1], "rb") as f:
    sys.exit(0 if "dev" in tomllib.load(f).get("project", {}).get("optional-dependencies", {}) else 1)
PY_DEV
  then
    py_install='pip install -e ".[dev]" allure-pytest'
  else
    py_guessed=1
    if [[ -f "$target/requirements-dev.txt" ]]; then
      py_install="pip install$([[ -f "$target/requirements.txt" ]] && echo ' -r requirements.txt') -r requirements-dev.txt pytest allure-pytest"
    elif [[ -f "$target/requirements.txt" ]]; then
      py_install='pip install -r requirements.txt pytest allure-pytest'
    else
      py_install='pip install -e . pytest allure-pytest'
    fi
  fi
fi

# 雛形の __ALLURE_REPORT_JOB__（report ジョブ）と __PY_INSTALL__ を埋めて置く
render_wf() {
  local name="$1" out="$wf_dir/$2"
  mkdir -p "$wf_dir"
  python3 - "$ds/templates/github/workflows/$name.$tpl_lang.yml" "$ds/templates/github/allure-report-job.yml" "$out" "$py_install" <<'PY'
import sys
tpl, job, out, py_install = sys.argv[1:]
body = "\n".join(l for l in open(job, encoding="utf-8").read().splitlines() if not l.startswith("#"))
s = open(tpl, encoding="utf-8").read().replace("__ALLURE_REPORT_JOB__", body).replace("__PY_INSTALL__", py_install)
open(out, "w", encoding="utf-8").write(s)
PY
  log "置いた: .github/workflows/$2"
}

tpl_hint="$ds/templates/github/workflows/ の test-report.${tpl_lang:-python}.yml と test-l3.${tpl_lang:-python}.yml"
if [[ -e "$wf_dir/test-report.yml" ]]; then
  log "そのまま: .github/workflows/test-report.yml（既にある）"
  grep -qs "fr_trace.py" "$wf_dir/test-report.yml" \
    || todo+=("test-report.yml に「FR・受け入れシナリオごとのテストの有無」（python3 tools/fr_trace.py --summary \"\$GITHUB_STEP_SUMMARY\"）のジョブを足す（.claude/rules/testing.md §8。雛形: $tpl_hint の fr-trace ジョブ）")
  [[ -e "$wf_dir/test-l3.yml" ]] \
    || todo+=("test-report.yml を L0〜L2 だけにし、L3 を test-l3.yml に分ける（.claude/rules/testing.md §6.4。雛形: $tpl_hint）")
  for wf in test-report.yml test-l3.yml; do
    [[ -e "$wf_dir/$wf" ]] && ! grep -qs "actions/download-artifact" "$wf_dir/$wf" \
      && todo+=("$wf のテストの実行と Allure レポートを別のジョブに分ける（test が out/allure-results/ を artifact で渡し、report が受け取って作る。雛形: $tpl_hint）")
  done
elif compgen -G "$wf_dir/*.yml" >/dev/null || compgen -G "$wf_dir/*.yaml" >/dev/null; then
  todo+=("既存の CI のテストジョブの最後で out/allure-results/ を artifact「allure-results」として上げ、$ds/templates/github/allure-report-job.yml の report ジョブを足す（CI が既にあるので新しい workflow は置いていない。テストのジョブ名が test でなければ needs を合わせる）")
  todo+=("既存の CI の L0〜L2 のワークフローに「FR・受け入れシナリオごとのテストの有無」（python3 tools/fr_trace.py --summary \"\$GITHUB_STEP_SUMMARY\"）のジョブを足す（.claude/rules/testing.md §8。雛形: $tpl_hint の fr-trace ジョブ）")
  todo+=("既存の CI のテストを L0〜L2 だけにし、L3 は別のワークフローにする（.claude/rules/testing.md §6.4。雛形: $tpl_hint）")
elif [[ -n "$lang" ]]; then
  render_wf test-report test-report.yml
  render_wf test-l3 test-l3.yml
  [[ $py_guessed -eq 0 ]] \
    || todo+=("test-report.yml と test-l3.yml の「依存を入れる」（${py_install}）がリポジトリに合っているか確かめる（pyproject.toml の optional-dependencies に dev が無いので推測した）")
  todo+=("test-l3.yml の paths を docs/testing/strategy.md の対応表と共通のコードに合わせ、L3 が使う secrets を登録する")
fi

# ミューテーションテストは別のワークフロー（定期実行で全体をやり直すため。既存の CI があっても置く）
if [[ -n "$lang" ]]; then
  if [[ -e "$wf_dir/mutation.yml" ]]; then
    log "そのまま: .github/workflows/mutation.yml（既にある）"
  else
    render_wf mutation mutation.yml
  fi
fi

# 5. コミット・PR の書き方（.claude/rules/git.md）
place "$ds/templates/github/pull_request_template.md" ".github/pull_request_template.md"
place "$ds/templates/github/workflows/pr-title.yml" ".github/workflows/pr-title.yml"

# 6. GitHub Actions の固定（actions.lock）
place "$ds/templates/github/workflows/verify-lockfile.yml" ".github/workflows/verify-lockfile.yml"
place "$ds/templates/github/dependabot.yml" ".github/dependabot.yml"
if [[ ! -f "$target/.github/workflows/actions.lock" ]] || [[ -n "$(cd "$target" && git status --porcelain -- .github/workflows 2>/dev/null)" ]]; then
  todo+=("gh actions-lock を実行して .github/workflows/actions.lock を作り直し、同じ PR でコミットする（gh extension install github/gh-actions-lock）")
fi

# 7. .gitignore と版の記録
if ! grep -qsxE '/?out/?' "$target/.gitignore"; then
  { [[ -s "$target/.gitignore" ]] && echo; echo '# dev-standards: テスト結果（Allure・JUnit）'; echo 'out/'; } >> "$target/.gitignore"
  log "追記: .gitignore（out/）"
fi
if [[ "$lang" == *python* ]] && ! grep -qsxE '/?mutants/?' "$target/.gitignore"; then
  { echo; echo '# dev-standards: mutmut の作業場所（ミューテーションテスト）'; echo 'mutants/'; } >> "$target/.gitignore"
  log "追記: .gitignore（mutants/）"
fi
if ! compgen -G "$target/tests/l[0-4]" >/dev/null || [[ ! -f "$target/docs/testing/strategy.md" ]]; then
  todo+=("テストを tests/l0〜l4 に置き、機能ごとの対応表を docs/testing/strategy.md に書く（.claude/rules/testing.md §6）")
fi
printf 'version: %s\nspeckit: %s\n' "$version" "$speckit_version" > "$target/.dev-standards"
log "書いた: .dev-standards（$version）"

echo
echo "== 残りの手順 =="
if [[ ${#todo[@]} -eq 0 ]]; then
  echo "なし"
else
  for t in "${todo[@]}"; do echo "- $t"; done
fi
echo "- 変更をブランチにコミットして PR にする"
