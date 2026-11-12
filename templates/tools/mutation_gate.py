#!/usr/bin/env python3
"""dev-standards: ミューテーションテストの結果のうち、変更したコードで生き残ったミュータントを見つける。

    python3 tools/mutation_gate.py [--base <git の比較元>] [--stryker <mutation.json>] [--mutmut]
                                   [--summary <ファイル>] [--out <出し先>]

決まりは dev-standards の .claude/rules/testing.md §10。bootstrap.sh が tools/mutation_gate.py として置く。
標準ライブラリだけで動く（Python 3.9 以上）。ミューテーションテストそのものは流さない（StrykerJS・mutmut が流す）。

- --stryker：StrykerJS の JSON レポート（mutation-testing-report-schema）を読む。ミュータントの位置（行）で突き合わせる。
- --mutmut：`mutmut results --all true` と `mutmut show` を呼ぶ。mutmut 3 は関数ごとにミュータントを作るので、
  変更した行を含む関数（クラスのメソッドを含む）で突き合わせる。
- --base：`git diff <base>...HEAD` の変更した行を「変更したコード」とする。無ければ全体の表だけ出して終了コード 0（週1回の全体実行など）。
- 変更したコードに、生き残り（Stryker の Survived・NoCoverage・Pending、mutmut の survived・no tests・not checked）があれば終了コード 1。
  除外コメントで外したもの（Stryker の Ignored と理由）は表に出すだけで落とさない。
- 表（Markdown）は標準出力と --summary のファイルに、生き残りの一覧（mutmut は差分つき）は <出し先>/survivors.md に書く。
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

STRYKER_FAIL = {"Survived", "NoCoverage", "Pending"}
STRYKER_DETECTED = {"Killed", "Timeout"}
STRYKER_INVALID = {"CompileError", "RuntimeError", "Ignored"}
MUTMUT_FAIL = {"survived", "no tests", "not checked"}
MUTMUT_DETECTED = {"killed", "timeout"}
MUTMUT_LINE = re.compile(r"^\s*(\S+__mutmut_\d+):\s*(.+?)\s*$")
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
CLASS_SEP = "ǁ"  # mutmut 3 の名前の区切り（mutmut/mutation/trampoline_templates.py の CLASS_NAME_SEPARATOR）


@dataclass
class Mutant:
    tool: str
    file: str
    where: str  # 行の範囲（Stryker）か関数名（mutmut）
    mutator: str
    status: str
    detail: str = ""
    changed: bool = False


def changed_lines(base: str) -> dict[str, set[int]]:
    """git diff <base>...HEAD で足した・変えた行（新しい側の行番号）をファイルごとに返す。"""
    out = subprocess.run(["git", "diff", "-U0", "--no-color", "--no-ext-diff", f"{base}...HEAD"],
                         check=True, capture_output=True, text=True).stdout
    result: dict[str, set[int]] = {}
    current = None
    for line in out.splitlines():
        if line.startswith("+++ "):
            path = line[4:]
            current = None if path == "/dev/null" else path[2:] if path.startswith("b/") else path
            if current is not None:
                result.setdefault(current, set())
        elif current is not None:
            m = HUNK.match(line)
            if m:
                start, count = int(m.group(1)), int(m.group(2) or "1")
                result[current].update(range(start, start + count))
    return result


def read_stryker(path: Path) -> list[Mutant]:
    report = json.loads(path.read_text(encoding="utf-8"))
    root = Path(report.get("projectRoot") or ".").resolve()
    mutants = []
    for name, f in report.get("files", {}).items():
        p = Path(name)
        rel = os.path.relpath(p if p.is_absolute() else root / p, Path.cwd().resolve())
        for m in f.get("mutants", []):
            loc = m.get("location", {})
            a, b = loc.get("start", {}).get("line", 0), loc.get("end", {}).get("line", 0)
            replacement = m.get("replacement")
            if m.get("status") == "Ignored":
                detail = m.get("statusReason") or ""
            else:
                detail = f"→ `{replacement}`" if isinstance(replacement, str) else ""
            mutants.append(Mutant("stryker", Path(rel).as_posix(), f"{a}-{b}" if a != b else str(a),
                                  m.get("mutatorName", ""), m.get("status", ""), detail.replace("\n", " ")))
    return mutants


def stryker_lines(m: Mutant) -> set[int]:
    a, _, b = m.where.partition("-")
    return set(range(int(a), int(b or a) + 1))


def mutmut_module(path: str) -> str:
    """mutmut 3 の get_mutant_name と同じ規則でファイルからモジュール名を作る（src. を外し、.__init__ は除く）。"""
    module = path[: -len(".py")].replace("/", ".")
    if module.startswith("src."):
        module = module[len("src."):]
    if module.endswith(".__init__"):
        module = module[: -len(".__init__")]
    return module


def function_ranges(source: str) -> list[tuple[str, int, int]]:
    """トップレベルの関数とクラスのメソッドを、mutmut 3 の名前（x_<関数>・xǁ<クラス>ǁ<メソッド>）と行の範囲で返す。"""
    funcs = (ast.FunctionDef, ast.AsyncFunctionDef)
    out = []

    def span(node: ast.AST) -> tuple[int, int]:
        first = min([node.lineno] + [d.lineno for d in getattr(node, "decorator_list", [])])
        return first, getattr(node, "end_lineno", node.lineno)

    for node in ast.parse(source).body:
        if isinstance(node, funcs):
            out.append((f"x_{node.name}", *span(node)))
        elif isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, funcs):
                    out.append((f"x{CLASS_SEP}{node.name}{CLASS_SEP}{item.name}", *span(item)))
    return out


def changed_mutmut_functions(changes: dict[str, set[int]]) -> dict[str, str]:
    """変更した行を含む関数の mutmut の名前（モジュール.関数）→ ファイルのパス。"""
    result = {}
    for path, lines in changes.items():
        if not path.endswith(".py") or not lines or not Path(path).is_file():
            continue
        try:
            ranges = function_ranges(Path(path).read_text(encoding="utf-8"))
        except SyntaxError:
            continue
        module = mutmut_module(path)
        for name, a, b in ranges:
            if lines & set(range(a, b + 1)):
                result[f"{module}.{name}"] = path
    return result


def read_mutmut() -> list[Mutant]:
    out = subprocess.run(["mutmut", "results", "--all", "true"], check=True, capture_output=True, text=True).stdout
    mutants = []
    for line in out.splitlines():
        m = MUTMUT_LINE.match(line)
        if m:
            name, status = m.groups()
            func = name.partition("__mutmut_")[0]
            mutants.append(Mutant("mutmut", "", func, name, status))
    return mutants


def score(mutants: list[Mutant]) -> str:
    if not mutants:
        return "ミュータントなし"
    if mutants[0].tool == "stryker":
        valid = [m for m in mutants if m.status not in STRYKER_INVALID]
        detected = sum(m.status in STRYKER_DETECTED for m in valid)
    else:
        valid = [m for m in mutants if m.status != "skipped"]
        detected = sum(m.status in MUTMUT_DETECTED for m in valid)
    pct = 100.0 * detected / len(valid) if valid else 0.0
    return f"{pct:.1f}%（検出 {detected} / 有効 {len(valid)}）"


def esc(s: str) -> str:
    return s.replace("|", "\\|")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", help="git の比較元（PR の比較先ブランチ、push の前のコミットなど）。無ければ全体の表だけ出す")
    ap.add_argument("--stryker", type=Path, help="StrykerJS の JSON レポート（例 out/mutation/mutation.json）")
    ap.add_argument("--mutmut", action="store_true", help="mutmut 3 の結果を読む（mutants/ のある場所で実行する）")
    ap.add_argument("--summary", type=Path, help="表を書き足すファイル（GitHub Actions の $GITHUB_STEP_SUMMARY）")
    ap.add_argument("--out", type=Path, default=Path("out/mutation"), help="生き残りの一覧の出し先（既定 out/mutation）")
    args = ap.parse_args()
    if not args.stryker and not args.mutmut:
        ap.error("--stryker か --mutmut のどちらかが要ります")

    base = args.base if args.base and set(args.base) != {"0"} else None
    changes = changed_lines(base) if base else {}

    groups: list[tuple[str, list[Mutant]]] = []
    if args.stryker:
        ms = read_stryker(args.stryker)
        for m in ms:
            m.changed = bool(changes.get(m.file, set()) & stryker_lines(m))
        groups.append(("StrykerJS", ms))
    if args.mutmut:
        ms = read_mutmut()
        targets = changed_mutmut_functions(changes)
        for m in ms:
            m.file = targets.get(m.where, "")
            m.changed = m.where in targets
        groups.append(("mutmut", ms))
        args.out.mkdir(parents=True, exist_ok=True)
        if subprocess.run(["mutmut", "export-cicd-stats"], capture_output=True).returncode == 0 \
                and Path("mutants/mutmut-cicd-stats.json").is_file():
            shutil.copy("mutants/mutmut-cicd-stats.json", args.out / "mutmut-cicd-stats.json")

    fail_states = {"stryker": STRYKER_FAIL, "mutmut": MUTMUT_FAIL}
    lines = ["## ミューテーションテスト（testing.md §10）", ""]
    lines.append(f"変更したコード：`git diff {base}...HEAD`" if base else "変更したコードの比較元なし（全体の表だけ出す。落とさない）")
    lines.append("")
    failures: list[Mutant] = []
    survivors_doc = ["# 生き残ったミュータント", ""]
    for title, ms in groups:
        lines.append(f"### {title}：全体のスコア {score(ms)}")
        lines.append("")
        rows = [m for m in ms if m.status in fail_states[m.tool] or m.status == "Ignored"]
        shown = [m for m in rows if m.changed] if base else rows
        failures += [m for m in shown if base and m.status in fail_states[m.tool]]
        if not shown:
            lines.append("変更したコードに生き残り・除外はありません。" if base else "生き残り・除外はありません。")
        else:
            lines += ["| 状態 | ファイル | 場所 | ミュータント | 内容・除外の理由 |", "|---|---|---|---|---|"]
            for m in shown:
                mark = "⚪ 除外" if m.status == "Ignored" else f"❌ {m.status}"
                lines.append(f"| {mark} | {esc(m.file)} | {esc(m.where)} | {esc(m.mutator)} | {esc(m.detail)} |")
        lines.append("")
        for m in rows:
            if m.status == "Ignored":
                continue
            survivors_doc.append(f"- [{m.tool}] {m.status} {m.file} {m.where} {m.mutator} {m.detail}".rstrip())
            if m.tool == "mutmut":
                diff = subprocess.run(["mutmut", "show", m.mutator], capture_output=True, text=True).stdout.strip()
                survivors_doc += ["", "```diff", diff, "```", ""]
    if base:
        lines.append(f"**変更したコードの生き残り：{len(failures)} 件**" + (
            "（テストを足して殺すか、等価なら理由付きの除外コメントで外す）" if failures else ""))
    text = "\n".join(lines) + "\n"
    print(text)
    if args.summary:
        with args.summary.open("a", encoding="utf-8") as f:
            f.write(text)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "survivors.md").write_text("\n".join(survivors_doc) + "\n", encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
