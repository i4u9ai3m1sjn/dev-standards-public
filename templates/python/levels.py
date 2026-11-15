"""dev-standards: テストの置き場所（tests/l0〜l4）から依存レベルの marker を付け、manual を既定で外す。

tests/conftest.py の pytest_plugins に "tests.levels" を足すと有効になる（bootstrap.sh が追記する）。
決まりは dev-standards の .claude/rules/testing.md §6。

- tests/l0/ 〜 tests/l4/ の下のテストに marker l0〜l4 を付ける（`pytest -m "l0 or l1 or l2"` でも選べる）。
- @pytest.mark.manual のテストは、環境変数 RUN_MANUAL=1 のときだけ実行し、それ以外は理由付きで skip する
  （manual ＝ 既定の実行から外し、明示したときだけ動かす。付けた理由は docs/testing/strategy.md）。
- marker ac（受け入れシナリオの E2E、testing.md §1）もここで登録する（pyproject に書かなくても --strict-markers で落ちない）。
- tests/l0〜l4 の外に置いたテストには何も付けない。移行中は
  `pytest --co -q -m "not l0 and not l1 and not l2 and not l3"` で置き場所の決まっていないテストを探せる。
- 移行が終わったら `--require-level`（pyproject の addopts に入れてよい）を付けると、
  tests/l0〜l4 の外にあるテストを見つけたときに収集エラーにする（-m で黙って外れるのを防ぐ）。
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

LEVELS = {  # Microsoft の DevOps のテスト分類（.claude/rules/testing.md §6.1）
    "l0": "L0: 速いメモリ内の単体テスト（tests/l0）",
    "l1": "L1: 対象のコードだけに依存する単体テスト（tests/l1）",
    "l2": "L2: ローカルの依存を使う、分離された機能テスト（tests/l2）",
    "l3": "L3: テスト用にデプロイしたサービス・外部のテスト用環境に対する機能テスト（tests/l3）",
    "l4": "L4: 本番に対するテスト（tests/l4）",
}
MANUAL_ENV = "RUN_MANUAL"


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--require-level",
        action="store_true",
        default=False,
        help="dev-standards: tests/l0〜l4 の外にあるテストを収集エラーにする",
    )


def pytest_configure(config: pytest.Config) -> None:
    for name, desc in LEVELS.items():
        config.addinivalue_line("markers", f"{name}: {desc}")
    config.addinivalue_line("markers", "ac: 受け入れシナリオ（US<n>/AC<m>）の E2E（.claude/rules/testing.md §1）")
    config.addinivalue_line(
        "markers", f"manual: 既定の実行から外し、{MANUAL_ENV}=1 のときだけ実行する（理由は docs/testing/strategy.md）"
    )


def _level_of(path: Path, rootpath: Path) -> str | None:
    try:
        parts = path.relative_to(rootpath).parts
    except ValueError:
        parts = path.parts
    # tests/<level>/... の形だけを見る（途中のディレクトリ名が偶然 l0 などでも拾わない）
    for i, part in enumerate(parts[:-1]):
        if part == "tests" and i + 1 < len(parts) - 1 and parts[i + 1] in LEVELS:
            return parts[i + 1]
    return None


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    run_manual = os.environ.get(MANUAL_ENV) == "1"
    unplaced: list[str] = []
    skip_manual = pytest.mark.skip(
        reason=f"manual: {MANUAL_ENV}=1 のときだけ実行する（理由と、誰がいつ流すかは docs/testing/strategy.md）"
    )
    for item in items:
        level = _level_of(Path(str(item.path)), config.rootpath)
        if level:
            item.add_marker(getattr(pytest.mark, level))
        else:
            unplaced.append(item.nodeid)
        if not run_manual and item.get_closest_marker("manual"):
            item.add_marker(skip_manual)
    if unplaced and config.getoption("--require-level"):
        listed = "\n  ".join(unplaced)
        raise pytest.UsageError(
            f"--require-level: tests/l0〜l4 の外にあるテストがあります（.claude/rules/testing.md §6.3）:\n  {listed}"
        )
