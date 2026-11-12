"""dev-standards: pytest で Allure レポートを見やすくする小さな補助。

tests/conftest.py に次の1行を書くと有効になる（bootstrap.sh が追記する）::

    pytest_plugins = ["tests.allure_support"]

- テスト関数の docstring の1行目を、Allure の表示名（title）にする。
  例: '''[001-x/FR-003] US1/AC2 色を指定せずに登録するとバナナ色になる'''
- 同じ1行目を JUnit XML の <property name="title"> にも書く（トレース用。
  pytest の JUnit の name は関数名なので、FR 番号はここから拾う）。
- pytest の marker（例: @pytest.mark.ac）は allure-pytest がタグとして表示する。
- 統合テスト・E2E で証跡を残すときは attach_json / attach_text / attach_command を使う。
"""

from __future__ import annotations

import json
from typing import Any

import allure
import pytest

_SECRET_KEYS = ("token", "secret", "password", "authorization", "api_key", "webhook")


def _mask(obj: Any) -> Any:
    if isinstance(obj, dict):
        return {
            k: ("***" if any(s in str(k).lower() for s in _SECRET_KEYS) else _mask(v))
            for k, v in obj.items()
        }
    if isinstance(obj, list):
        return [_mask(v) for v in obj]
    return obj


def attach_json(name: str, obj: Any) -> None:
    """辞書・リストを JSON として添付する（秘密らしいキーは *** に置き換える）。"""
    allure.attach(
        json.dumps(_mask(obj), ensure_ascii=False, indent=2, default=str),
        name=name,
        attachment_type=allure.attachment_type.JSON,
    )


def attach_text(name: str, text: str) -> None:
    """標準出力・ログなどの文字列を添付する。"""
    allure.attach(text, name=name, attachment_type=allure.attachment_type.TEXT)


def attach_command(args: Any, returncode: int, stdout: str = "", stderr: str = "") -> None:
    """CLI を実行した E2E の証跡（コマンド・終了コード・標準出力・標準エラー）を添付する。"""
    cmd = args if isinstance(args, str) else " ".join(str(a) for a in args)
    attach_text("command", cmd)
    attach_text("exit code", str(returncode))
    attach_text("stdout", stdout or "")
    if stderr:
        attach_text("stderr", stderr)


def _title(item: pytest.Item) -> str | None:
    func = getattr(item, "function", None)
    doc = func.__doc__ if func else None
    if doc and doc.strip():
        return doc.strip().splitlines()[0].strip()
    return None


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        title = _title(item)
        if title:
            item.user_properties.append(("title", title))


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_call(item: pytest.Item):
    title = _title(item)
    if title:
        allure.dynamic.title(title)
    yield
