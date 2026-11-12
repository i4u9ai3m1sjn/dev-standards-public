#!/bin/bash
# dev-standards: bootstrap.sh と雛形（levels.py・allure_support.py・テストのワークフロー）を、試験用リポジトリに入れて確かめる。
#
#   bash bootstrap/selftest.sh
#
# 要るもの: specify（speckit/VERSION の版）、git、python3 と pytest・allure-pytest・PyYAML が入った環境。
# CI（.github/workflows/ci.yml の bootstrap ジョブ）と手元のどちらでも動く。失敗したら exit 1。
set -euo pipefail

ds="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
ok() { echo "ok   - $*"; }
ng() { echo "FAIL - $*"; fails=$((fails + 1)); }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else ng "$desc"; fi; }

new_repo() {
  local dir="$work/$1"
  mkdir -p "$dir" && git -C "$dir" init -q
  echo "$dir"
}

# 1. Python のリポジトリ（pyproject の optional-dependencies に dev がある）
py="$(new_repo py)"
cat >"$py/pyproject.toml" <<'EOF'
[project]
name = "sample"
version = "0.0.0"
[project.optional-dependencies]
dev = ["pytest"]
EOF
mkdir -p "$py/tests/l0" "$py/tests/l3" "$py/tests/old"
cat >"$py/tests/l0/test_policy_check.py" <<'EOF'
import pytest


def test_l0():
    """[001-x/FR-001] L0 のテスト"""


@pytest.mark.ac
def test_ac():
    """[001-x/FR-002] US1/AC1 受け入れシナリオ"""


@pytest.mark.manual
def test_manual():
    """[001-x/FR-003] 人が流すテスト"""
EOF
cat >"$py/tests/l3/test_policy_remote.py" <<'EOF'
def test_l3():
    """[001-x/FR-004] L3 のテスト"""
EOF
cat >"$py/tests/old/test_legacy.py" <<'EOF'
def test_old():
    pass
EOF

bash "$ds/bootstrap/bootstrap.sh" "$py" >"$work/py.log" 2>&1 || { cat "$work/py.log"; ng "bootstrap.sh（Python）が終了コード 0 で終わる"; }
for f in .specify .dev-standards allurerc.mjs tests/allure_support.py tests/levels.py tests/conftest.py tools/fr_trace.py \
  .github/workflows/test-report.yml .github/workflows/test-l3.yml .github/workflows/pr-title.yml \
  .github/workflows/verify-lockfile.yml .github/dependabot.yml .github/pull_request_template.md; do
  check "置かれる: $f" test -e "$py/$f"
done
check ".dev-standards に VERSION の版が書かれる" grep -qx "version: $(cat "$ds/VERSION")" "$py/.dev-standards"
check ".gitignore に out/ が入る" grep -qx "out/" "$py/.gitignore"
check "依存は .[dev] で入れる" grep -q 'pip install -e ".\[dev\]" allure-pytest' "$py/.github/workflows/test-report.yml"
check "ac marker の登録を残りの手順に出さない" bash -c "! grep -q 'markers に ac' '$work/py.log'"

# ワークフローが YAML として読め、§6.4 の形になっている
python3 - "$py/.github/workflows" <<'PY' && ok "test-report.yml・test-l3.yml が §6.4 の形" || ng "test-report.yml・test-l3.yml が §6.4 の形"
import sys, yaml
d = sys.argv[1]
r = yaml.safe_load(open(f"{d}/test-report.yml"))
l3 = yaml.safe_load(open(f"{d}/test-l3.yml"))
on_r, on_l3 = r[True], l3[True]  # YAML 1.1 では on: が True になる
run_r = "\n".join(s.get("run", "") for s in r["jobs"]["test"]["steps"])
job = l3["jobs"]["test"]
run_l3 = "\n".join(s.get("run", "") for s in job["steps"])
assert 'pytest -m "not l3 and not l4"' in run_r, "L0〜L2 だけ"
assert "schedule" not in on_r
assert on_l3["pull_request"]["paths"], "PR は paths で絞る"
assert on_l3["push"]["branches"] == ["main"]
assert on_l3["schedule"] and "workflow_dispatch" in on_l3
assert "dependabot[bot]" in job["if"] and "head.repo.full_name" in job["if"] and "event_name != 'pull_request'" in job["if"]
assert "pytest -m l3" in run_l3 and "[ $? -eq 5 ]" in run_l3, "テストが無くても緑"
assert "fr_trace.py" not in run_r, "fr_trace はテストのジョブに入れない"
assert "python3 tools/fr_trace.py" in "\n".join(s.get("run", "") for s in r["jobs"]["fr-trace"]["steps"]), "FR・受け入れシナリオごとのテストの有無（testing.md §8）"
# テストの実行と Allure レポートを別のジョブに分ける（test が artifact で渡し、report が受け取る）
for w in (r, l3):
    assert "allure generate" not in "\n".join(s.get("run", "") for s in w["jobs"]["test"]["steps"]), "テストのジョブでレポートを作らない"
    up = [s for s in w["jobs"]["test"]["steps"] if s.get("uses", "").startswith("actions/upload-artifact@")]
    assert up and up[0]["with"]["name"] == "allure-results" and up[0]["if"] == "always()"
    rep = w["jobs"]["report"]
    assert rep["needs"] == "test" and rep["if"] == "always() && needs.test.result != 'skipped'"
    steps = rep["steps"]
    dl = [s for s in steps if s.get("uses", "").startswith("actions/download-artifact@")]
    assert dl and dl[0]["with"]["name"] == "allure-results"
    assert any(s.get("with", {}).get("sparse-checkout") == "allurerc.mjs" for s in steps), "allurerc.mjs を読む"
    assert any("allure@" in s.get("run", "") and "generate" in s.get("run", "") for s in steps)
assert "__" not in open(f"{d}/test-report.yml").read() + open(f"{d}/test-l3.yml").read(), "置き換え漏れ"
PY

# pytest（levels.py・allure_support.py）
pytest_in() { (cd "$py" && python3 -m pytest -p no:cacheprovider "$@"); }
out="$(pytest_in -q -rs -m "not l3 and not l4" --strict-markers --alluredir=out/allure-results --junitxml=out/junit.xml 2>&1 || true)"
check "L0〜L2 の実行で L3 が外れ、置き場所未定のテストは流れる" grep -qE "3 passed, 1 skipped, 1 deselected" <<<"$out"
check "manual は理由付きで skip" grep -q "manual: RUN_MANUAL=1" <<<"$out"
check "--strict-markers でも ac で落ちない" bash -c "! grep -q \"'ac' not found\" <<<\"\$1\"" _ "$out"
check "JUnit XML に docstring 1行目の title が出る" grep -q 'name="title" value="\[001-x/FR-001\] L0 のテスト"' "$py/out/junit.xml"
check "Allure の結果が出る" compgen -G "$py/out/allure-results/*-result.json"

# FR・受け入れシナリオごとのテストの有無（tools/fr_trace.py。testing.md §8）
trace() { (cd "$py" && python3 -I tools/fr_trace.py "$@"); }
mkdir -p "$py/specs/001-x"
# spec_x <Status> <US1 のシナリオ数> <FR...>
spec_x() {
  printf '# x\n\n**Status**: %s\n\n### User Story 1 - x (Priority: P1)\n\n**Acceptance Scenarios**:\n\n' "$1"
  for ((i = 1; i <= $2; i++)); do echo "$i. **Given** x, **When** y, **Then** z"; done
  printf '\n---\n\n## Requirements\n\n'; shift 2; for fr in "$@"; do echo "- **$fr**: System MUST x"; done
}
spec_x Implemented 1 FR-001 FR-002 FR-003 FR-004 >"$py/specs/001-x/spec.md"
rc=0; trace >"$work/trace1.log" 2>&1 || rc=$?
check "fr_trace: すべての FR・AC にテストがあれば Implemented でも緑（manual・L3 も数える）" test "$rc" = 0
check "fr_trace: テストのあるレベルを出す" bash -c "grep -q '| FR-001 | ✅ あり | l0 |' '$work/trace1.log' && grep -q '| FR-004 | ✅ あり | l3 |' '$work/trace1.log' && grep -q '| US1/AC1 | ✅ あり | l0 |' '$work/trace1.log'"
spec_x Implemented 1 FR-001 FR-002 FR-003 FR-004 FR-005 >"$py/specs/001-x/spec.md"
rc=0; trace >"$work/trace2.log" 2>&1 || rc=$?
check "fr_trace: Implemented でテストの無い FR があると終了コード 1" bash -c "[[ $rc -eq 1 ]] && grep -q '| FR-005 | ❌ なし' '$work/trace2.log'"
spec_x Implemented 2 FR-001 FR-002 FR-003 FR-004 >"$py/specs/001-x/spec.md"
rc=0; trace >"$work/trace2b.log" 2>&1 || rc=$?
check "fr_trace: Implemented でテストの無い AC があると終了コード 1" bash -c "[[ $rc -eq 1 ]] && grep -q '| US1/AC2 | ❌ なし' '$work/trace2b.log'"
spec_x Draft 2 FR-001 FR-002 FR-003 FR-004 FR-005 >"$py/specs/001-x/spec.md"
rc=0; trace --summary "$work/summary.md" >/dev/null 2>&1 || rc=$?
check "fr_trace: Draft なら表に出すだけで緑（--summary に書く）" bash -c "[[ $rc -eq 0 ]] && grep -q 'FR・受け入れシナリオごとのテスト' '$work/summary.md'"
spec_x Implemented 1 FR-001 FR-002 FR-003 FR-004 >"$py/specs/001-x/spec.md"
printf 'def test_typo():\n    """[001-x/FR-099] 打ち間違い"""\n\ndef test_typo_ac():\n    """[001-x/FR-002] US1/AC9 打ち間違い"""\n' >"$py/tests/l0/test_typo.py"
rc=0; trace >"$work/trace3.log" 2>&1 || rc=$?
check "fr_trace: 存在しない FR・AC を指すタグで終了コード 1" bash -c "[[ $rc -eq 1 ]] && grep -q 'FR-099' '$work/trace3.log' && grep -q 'US1/AC9' '$work/trace3.log'"
rm -f "$py/tests/l0/test_typo.py"
out="$(RUN_MANUAL=1 pytest_in -q -m l0 2>&1 || true)"
check "RUN_MANUAL=1 で manual が動く" grep -q "3 passed" <<<"$out"
out="$(pytest_in -q -m l3 2>&1 || true)"
check "-m l3 で L3 だけ動く" grep -qE "1 passed, 4 deselected" <<<"$out"
rc=0; pytest_in -q --require-level >"$work/req.log" 2>&1 || rc=$?
check "--require-level で置き場所の外のテストが収集エラー" bash -c "[[ $rc -ne 0 ]] && grep -q 'tests/old/test_legacy.py' '$work/req.log'"

# --update をもう一度：上書きせず、preset の追記は1回だけ
cp "$py/.github/workflows/test-report.yml" "$work/before.yml"
bash "$ds/bootstrap/bootstrap.sh" --update "$py" >"$work/py2.log" 2>&1 || { cat "$work/py2.log"; ng "bootstrap.sh --update が終了コード 0 で終わる"; }
check "--update で test-report.yml を上書きしない" cmp -s "$work/before.yml" "$py/.github/workflows/test-report.yml"
n="$(grep -c "## 追加の規則：テストの置き場所" "$py/.claude/skills/speckit-tasks/SKILL.md" || true)"
check "preset の追記は1回だけ（$n 回）" test "$n" = 1
n="$(grep -c "tests.levels" "$py/tests/conftest.py" || true)"
check "conftest.py の追記は1回だけ（$n 回）" test "$n" = 1
n="$(grep -c "## 追加の規則：FR・受け入れシナリオごとのテスト" "$py/.claude/skills/speckit-converge/SKILL.md" || true)"
check "converge への preset の追記は1回だけ（$n 回）" test "$n" = 1

# ミューテーションテスト（testing.md §10）：mutation.yml・tools/mutation_gate.py
check "置かれる: tools/mutation_gate.py" test -e "$py/tools/mutation_gate.py"
check "置かれる: .github/workflows/mutation.yml" test -e "$py/.github/workflows/mutation.yml"
check ".gitignore に mutants/ が入る" grep -qx "mutants/" "$py/.gitignore"
check "[tool.mutmut] を足す手順を出す" grep -q "\[tool.mutmut\]" "$work/py.log"
python3 - "$py/.github/workflows/mutation.yml" <<'PY' && ok "mutation.yml が §10 の形" || ng "mutation.yml が §10 の形"
import sys, yaml
text = open(sys.argv[1]).read()
w = yaml.safe_load(text)
on = w[True]
assert "pull_request" in on and on["push"]["branches"] == ["main"] and on["schedule"] and "workflow_dispatch" in on
job = w["jobs"]["mutmut"]
runs = "\n".join(s.get("run", "") for s in job["steps"])
assert "mutmut run" in runs and "tools/mutation_gate.py --mutmut" in runs
assert "stryker" not in w["jobs"], "Python だけのリポジトリに Stryker は置かない"
restore = [s for s in job["steps"] if "cache/restore" in s.get("uses", "")][0]
assert "schedule" not in restore["if"] and "push" in restore["if"], "定期実行では前回の結果を戻さない"
assert "__" not in text, "置き換え漏れ"
PY

# 判定：変更したコードの生き残りだけで落とす（StrykerJS の JSON を模したもの）
gate="$(new_repo gate)"
mkdir -p "$gate/src" && printf 'a\nb\nc\nd\n' >"$gate/src/x.ts"
git -C "$gate" add -A && git -C "$gate" -c user.email=t@example.com -c user.name=t commit -qm base
gate_base="$(git -C "$gate" rev-parse --abbrev-ref HEAD)"
git -C "$gate" checkout -qb feat && printf 'a\nb\nC\nd\n' >"$gate/src/x.ts"
git -C "$gate" -c user.email=t@example.com -c user.name=t commit -qam change
python3 - "$gate/mutation.json" <<'PY'
import json, sys
def m(i, line, status, reason=None):
    d = {"id": str(i), "mutatorName": "ArithmeticOperator", "replacement": "a - 1", "status": status,
         "location": {"start": {"line": line, "column": 1}, "end": {"line": line, "column": 2}}}
    if reason:
        d["statusReason"] = reason
    return d
json.dump({"schemaVersion": "1.0", "thresholds": {"high": 80, "low": 60}, "files": {"src/x.ts": {"language": "typescript", "source": "",
  "mutants": [m(1, 1, "Survived"), m(2, 3, "Survived"), m(3, 3, "Killed"), m(4, 3, "Ignored", "等価")]}}}, open(sys.argv[1], "w"))
PY
rc=0; (cd "$gate" && python3 -I "$py/tools/mutation_gate.py" --stryker mutation.json --base "$gate_base" --summary "$work/msum.md") >"$work/gate1.log" 2>&1 || rc=$?
check "mutation_gate: 変更した行の生き残りで終了コード 1（変えていない行の生き残りは数えない）" \
  bash -c "[[ $rc -eq 1 ]] && grep -q '生き残り：1 件' '$work/gate1.log' && grep -q '| ❌ Survived | src/x.ts | 3 |' '$work/gate1.log' && ! grep -q '| src/x.ts | 1 |' '$work/gate1.log'"
check "mutation_gate: 除外は理由付きで表に出す" grep -q '| ⚪ 除外 | src/x.ts | 3 | ArithmeticOperator | 等価 |' "$work/msum.md"
rc=0; (cd "$gate" && python3 -I "$py/tools/mutation_gate.py" --stryker mutation.json --base "") >"$work/gate2.log" 2>&1 || rc=$?
check "mutation_gate: 比較元が無ければ全体の表だけで終了コード 0" bash -c "[[ $rc -eq 0 ]] && grep -q '| src/x.ts | 1 |' '$work/gate2.log'"

# mutmut を実際に流す（入っていれば。CI では入れる）
if command -v mutmut >/dev/null 2>&1; then
  mm="$(new_repo mm)"
  mkdir -p "$mm/src/calc" "$mm/tests/l0" "$mm/tests/l3"
  : >"$mm/src/calc/__init__.py"
  printf 'def double(x):\n    return x * 2\n\n\nclass Cart:\n    def count(self, items):\n        return len(items)\n' >"$mm/src/calc/core.py"
  printf 'from calc.core import double\n\n\ndef test_double():\n    """[001-x/FR-001] double"""\n    assert double(3) == 6\n' >"$mm/tests/l0/test_core.py"
  printf 'def test_ext():\n    assert False  # L3 は殺す側に入らない\n' >"$mm/tests/l3/test_ext.py"
  cp "$ds/templates/python/levels.py" "$mm/tests/" && : >"$mm/tests/__init__.py" && echo 'pytest_plugins = ["tests.levels"]' >"$mm/tests/conftest.py"
  cat >"$mm/pyproject.toml" <<'EOF'
[project]
name = "calc"
version = "0.0.0"
[tool.mutmut]
source_paths = ["src/"]
pytest_add_cli_args = ["-m", "not l3 and not l4"]
[tool.pytest.ini_options]
pythonpath = ["src", "."]
testpaths = ["tests"]
EOF
  printf 'mutants/\nout/\n__pycache__/\n' >"$mm/.gitignore"
  git -C "$mm" add -A && git -C "$mm" -c user.email=t@example.com -c user.name=t commit -qm base
  mm_base="$(git -C "$mm" rev-parse --abbrev-ref HEAD)"
  git -C "$mm" checkout -qb feat && sed -i 's/return len(items)/return len(items) + 0/' "$mm/src/calc/core.py"
  git -C "$mm" -c user.email=t@example.com -c user.name=t commit -qam change
  (cd "$mm" && mutmut run) >"$work/mutmut.log" 2>&1 || { tail -20 "$work/mutmut.log"; ng "mutmut run が終了コード 0 で終わる"; }
  rc=0; (cd "$mm" && python3 -I "$py/tools/mutation_gate.py" --mutmut --base "$mm_base") >"$work/gate3.log" 2>&1 || rc=$?
  check "mutation_gate（mutmut）: 変えたメソッドのテストの無いミュータントで終了コード 1、変えていない関数は数えない" \
    bash -c "[[ $rc -eq 1 ]] && grep -q 'xǁCartǁcount' '$work/gate3.log' && ! grep -q '❌.*x_double' '$work/gate3.log'"
  check "mutation_gate（mutmut）: 生き残りの差分と件数を out/mutation/ に出す" \
    bash -c "grep -q '^-' '$mm/out/mutation/survivors.md' && test -s '$mm/out/mutation/mutmut-cicd-stats.json'"
else
  echo "skip - mutmut が無いので mutmut を流す確認は省く（CI では入れる）"
fi

# 2. requirements.txt だけの Python リポジトリ：依存の入れ方を合わせ、確かめる手順を出す
rq="$(new_repo req)"
echo "requests" >"$rq/requirements.txt"
bash "$ds/bootstrap/bootstrap.sh" "$rq" >"$work/rq.log" 2>&1 || { cat "$work/rq.log"; ng "bootstrap.sh（requirements.txt）が終了コード 0 で終わる"; }
check "requirements.txt から依存を入れる" grep -q "pip install -r requirements.txt pytest allure-pytest" "$rq/.github/workflows/test-report.yml"
check "依存の入れ方を確かめる手順を出す" grep -q "「依存を入れる」" "$work/rq.log"

# 3. Python と Node が両方あるリポジトリ：pytest も CI に入る
both="$(new_repo both)"
cp "$py/pyproject.toml" "$both/"
echo '{"name":"sample","private":true}' >"$both/package.json"
bash "$ds/bootstrap/bootstrap.sh" "$both" >"$work/both.log" 2>&1 || { cat "$work/both.log"; ng "bootstrap.sh（Python＋Node）が終了コード 0 で終わる"; }
for wf in test-report test-l3; do
  check "Python＋Node の $wf.yml に pytest と Vitest が入る" \
    bash -c "grep -q 'pytest -m' '$both/.github/workflows/$wf.yml' && grep -q 'npx vitest run' '$both/.github/workflows/$wf.yml'"
done
check "Python＋Node の mutation.yml に mutmut と StrykerJS が入る" \
  bash -c "grep -q 'mutmut run' '$both/.github/workflows/mutation.yml' && grep -q 'npx stryker run' '$both/.github/workflows/mutation.yml'"
for f in stryker.config.json vitest.mutation.config.ts; do
  check "Node があれば置かれる: $f" test -e "$both/$f"
done

# 4. 既存の test-report.yml がある（0.1.0 で入れた）リポジトリ：L3 を分ける手順を出す
old="$(new_repo old)"
cp "$py/pyproject.toml" "$old/"
mkdir -p "$old/.github/workflows" && echo "name: test-report" >"$old/.github/workflows/test-report.yml"
bash "$ds/bootstrap/bootstrap.sh" "$old" >"$work/old.log" 2>&1 || { cat "$work/old.log"; ng "bootstrap.sh（既存の test-report.yml）が終了コード 0 で終わる"; }
check "既存の test-report.yml は上書きしない" grep -qx "name: test-report" "$old/.github/workflows/test-report.yml"
check "L3 を test-l3.yml に分ける手順を出す" grep -q "L3 を test-l3.yml に分ける" "$work/old.log"
check "既存の test-report.yml に FR ごとのテストの有無を足す手順を出す" grep -q "FR・受け入れシナリオごとのテストの有無" "$work/old.log"
check "既存の test-report.yml のテストとレポートを分ける手順を出す" grep -q "test-report.yml のテストの実行と Allure レポートを別のジョブに分ける" "$work/old.log"

echo
if [[ $fails -gt 0 ]]; then
  echo "失敗: $fails 件"
  exit 1
fi
echo "すべて通りました"
