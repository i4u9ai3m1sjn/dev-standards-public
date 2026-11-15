#!/usr/bin/env python3
"""dev-standards: spec.md の FR と受け入れシナリオ（US<n>/AC<m>）ごとに、テストが書かれているかを確かめる。

    python3 tools/fr_trace.py [--feature <featureディレクトリ名> ...] [--summary <ファイル>]

決まりは dev-standards の .claude/rules/testing.md §8。bootstrap.sh が tools/fr_trace.py として置く。
標準ライブラリだけで動く（Python 3.9 以上）。テストは流さず、テストの結果も読まない（結果は Allure で見る）。

- specs/*/spec.md から `**Status**:` と `**FR-###**`、各 User Story の Acceptance Scenarios（上から数えて US<n>/AC<m>）を読む。
- tests/l0〜l4 の下のファイルから `[<featureディレクトリ名>/FR-###]` を拾う（言語を問わず文字列として探す）。
  tests/ 直下の共通ファイル（allure_support.py の例など）や置き場所の外のテストは見ない（testing.md §6.3）。
  同じ行に `US<n>/AC<m>` があれば、その feature の受け入れシナリオのテストとして数える（テスト名は1行に書く）。
- FR・AC ごとに、テストのあるレベル（tests/l0〜l4 のディレクトリ名）を Markdown の表にして標準出力（と --summary のファイル）に出す。
- 次のときは終了コード 1：
  - Status が Implemented の feature に、テストの無い FR・AC がある
  - テストのタグが、存在しない feature・FR・AC を指している（打ち間違い）
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

TAG = re.compile(r"\[([A-Za-z0-9][A-Za-z0-9._-]*)/(FR-\d{3,})\]")
FR_LINE = re.compile(r"\*\*(FR-\d{3,})\*\*")
STATUS_LINE = re.compile(r"^\*\*Status\*\*:\s*(\S+)", re.MULTILINE)
STORY_HEAD = re.compile(r"^#+\s*User Story\s+(\d+)\b", re.IGNORECASE)
SCENARIOS_HEAD = re.compile(r"^\*\*Acceptance Scenarios\*\*", re.IGNORECASE)
SCENARIO_ITEM = re.compile(r"^\d+\.\s")
AC_TAG = re.compile(r"\bUS(\d+)/AC(\d+)\b")
SCAN_SUFFIXES = {".py", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".java", ".kt", ".go", ".cs", ".rb", ".php", ".rs", ".dart"}
SKIP_DIRS = {"node_modules", ".git", ".venv", "venv", "__pycache__", "out"}
LEVELS = ("l0", "l1", "l2", "l3", "l4")


@dataclass
class Feature:
    name: str
    status: str
    frs: list[str]
    acs: list[str] = field(default_factory=list)  # ["US1/AC1", "US1/AC2", …]
    found: dict[str, set[str]] = field(default_factory=dict)  # FR・AC → {"l0", "l3", …}

    @property
    def strict(self) -> bool:
        return self.status.lower() == "implemented"


def load_acs(text: str) -> list[str]:
    """User Story ごとの Acceptance Scenarios の番号付きの行を、上から US<n>/AC<m> と数える。"""
    acs: list[str] = []
    story, in_scenarios, m = None, False, 0
    for line in text.splitlines():
        head = STORY_HEAD.match(line)
        if head:
            story, in_scenarios, m = head.group(1), False, 0
        elif line.startswith("#") or line.strip() == "---":
            story, in_scenarios = None, False
        elif story and SCENARIOS_HEAD.match(line):
            in_scenarios = True
        elif story and in_scenarios and line.startswith("**"):
            in_scenarios = False
        elif story and in_scenarios and SCENARIO_ITEM.match(line):
            m += 1
            acs.append(f"US{story}/AC{m}")
    return acs


def load_features(specs: Path) -> dict[str, Feature]:
    features: dict[str, Feature] = {}
    for spec in sorted(specs.glob("*/spec.md")):
        text = spec.read_text(encoding="utf-8")
        m = STATUS_LINE.search(text)
        frs = list(dict.fromkeys(FR_LINE.findall(text)))  # 書かれた順、重複なし
        features[spec.parent.name] = Feature(spec.parent.name, m.group(1) if m else "?", frs, load_acs(text))
    return features


def scan_tests(tests: Path, features: dict[str, Feature], unknown: set[str]) -> None:
    for level in LEVELS:
        for path in level_files(tests / level):
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                acs = [f"US{n}/AC{m}" for n, m in AC_TAG.findall(line)]
                for feature, fr in TAG.findall(line):
                    f = features.get(feature)
                    if f is None or fr not in f.frs:
                        unknown.add(f"[{feature}/{fr}]（{path}）")
                        continue
                    f.found.setdefault(fr, set()).add(level)
                    for ac in acs:
                        if ac in f.acs:
                            f.found.setdefault(ac, set()).add(level)
                        else:
                            unknown.add(f"[{feature}] {ac}（{path}）")


def level_files(base: Path) -> list[Path]:
    files: list[Path] = []
    if base.is_dir():
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
            files += [Path(dirpath) / n for n in sorted(filenames) if Path(n).suffix in SCAN_SUFFIXES]
    return files


def levels_text(levels: set[str]) -> str:
    return ", ".join(lv for lv in LEVELS if lv in levels)


def render(features: list[Feature], unknown: set[str]) -> tuple[str, int]:
    lines = ["### FR・受け入れシナリオごとのテスト", ""]
    errors = 0
    if not features:
        lines.append("specs/*/spec.md がありません。")
    for f in features:
        items = f.frs + f.acs
        missing = [i for i in items if not f.found.get(i)]
        mark = "❌" if f.strict and missing else ("✅" if not missing else "⏳")
        have_fr = sum(1 for fr in f.frs if f.found.get(fr))
        have_ac = sum(1 for ac in f.acs if f.found.get(ac))
        lines.append(f"#### {mark} {f.name}（Status: {f.status}、テストのある FR {have_fr}/{len(f.frs)}・AC {have_ac}/{len(f.acs)}）")
        lines.append("")
        if not items:
            lines.append("spec.md に FR も受け入れシナリオもありません。")
        else:
            lines.append("| FR・AC | テスト | レベル |")
            lines.append("|---|---|---|")
            for i in items:
                levels = f.found.get(i, set())
                lines.append(f"| {i} | {'✅ あり' if levels else '❌ なし'} | {levels_text(levels)} |")
        if f.strict and missing:
            errors += len(missing)
            lines.append("")
            lines.append(f"Status が Implemented なのに、テストの無い FR・AC があります: {', '.join(missing)}")
        lines.append("")
    if unknown:
        errors += len(unknown)
        lines.append("#### ❌ 存在しない feature・FR・AC を指すテストのタグ")
        lines.append("")
        lines.extend(f"- {u}" for u in sorted(unknown))
        lines.append("")
    lines.append("テストの結果は Allure で見る。決まりは .claude/rules/testing.md §8。")
    return "\n".join(lines) + "\n", errors


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="spec.md の FR・受け入れシナリオごとに、テストが書かれているかを確かめる（testing.md §8）")
    p.add_argument("--specs", default="specs", help="Spec Kit の specs ディレクトリ（既定: specs）")
    p.add_argument("--tests", default="tests", help="テストのディレクトリ（この下の l0〜l4 を見る。既定: tests）")
    p.add_argument("--feature", action="append", help="表に出す feature（既定: すべて。複数可）")
    p.add_argument("--summary", help="Markdown を追記するファイル（CI では $GITHUB_STEP_SUMMARY）")
    a = p.parse_args(argv)

    features = load_features(Path(a.specs))
    unknown: set[str] = set()
    scan_tests(Path(a.tests), features, unknown)

    shown = list(features.values())
    if a.feature:
        missing = [n for n in a.feature if n not in features]
        if missing:
            print(f"specs/ にない feature: {', '.join(missing)}", file=sys.stderr)
            return 2
        shown = [features[n] for n in a.feature]
    text, errors = render(shown, unknown)
    print(text, end="")
    if a.summary:
        with open(a.summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
