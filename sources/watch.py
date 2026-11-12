"""dev-standards: 共通ルールが出典にしているページの本文を取り出し、前回の写しと比べる。

使い方:
  python3 sources/watch.py            # 取得して sources/snapshots/ を書き換える（差があれば終了コード 1）
  python3 sources/watch.py --check    # 書き換えずに比べるだけ（差があれば終了コード 1）
  python3 sources/watch.py --html-dir DIR  # 取得せず DIR/<id>.html を読む（試験用）

見張るページは sources/sources.json に書く。各ページは start〜end の id を持つ要素のあいだの本文だけを比べる
（ナビゲーション・更新日・フッターなど、本文と関係なく変わる部分で騒がないため）。
標準ライブラリだけで動く（GitHub Actions のランナーに追加のインストールが要らない）。
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SNAPSHOTS = ROOT / "snapshots"
BLOCK = {
    "p", "div", "section", "article", "li", "ul", "ol", "table", "tr", "pre", "blockquote",
    "h1", "h2", "h3", "h4", "h5", "h6", "dt", "dd", "dl", "br", "hr", "td", "th",
}
SKIP = {"script", "style", "noscript", "svg", "button", "nav", "template"}
VOID = {"br", "hr", "img", "input", "meta", "link", "source", "wbr"}


class _Extractor(HTMLParser):
    """id=start の要素から、id=end の要素の手前までの本文をブロックごとの行にする。"""

    def __init__(self, start: str, end: str) -> None:
        super().__init__(convert_charrefs=True)
        self.start, self.end = start, end
        self.capturing = False
        self.done = False
        self.skip_depth = 0
        self.stack: list[str] = []
        self.lines: list[str] = []
        self.buf: list[str] = []

    def _flush(self) -> None:
        text = re.sub(r"\s+", " ", "".join(self.buf).replace("\u200b", "")).strip()
        if text:
            self.lines.append(text)
        self.buf = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        ident = dict(attrs).get("id")
        if not self.done and ident == self.start:
            self.capturing = True
        elif self.capturing and ident == self.end:
            self._flush()
            self.capturing, self.done = False, True
        if tag in VOID:
            if self.capturing and tag in BLOCK:
                self._flush()
            return
        self.stack.append(tag)
        if tag in SKIP:
            self.skip_depth += 1
        if self.capturing and tag in BLOCK:
            self._flush()

    def handle_endtag(self, tag: str) -> None:
        if tag in VOID:
            return
        # 閉じ忘れのある HTML でも崩れないよう、対応する開きタグまで戻る
        if tag in self.stack:
            while self.stack:
                top = self.stack.pop()
                if top in SKIP:
                    self.skip_depth -= 1
                if top == tag:
                    break
        if self.capturing and tag in BLOCK:
            self._flush()

    def handle_data(self, data: str) -> None:
        if self.capturing and self.skip_depth == 0:
            self.buf.append(data)


def extract(html: str, start: str, end: str) -> str:
    p = _Extractor(start, end)
    p.feed(html)
    p.close()
    p._flush()
    if not p.lines:
        raise ValueError(f"id={start!r} から id={end!r} のあいだに本文が見つからない（ページの構成が変わった可能性）")
    if not p.done:
        raise ValueError(f"id={end!r} が見つからない（ページの構成が変わった可能性）")
    return "\n".join(p.lines) + "\n"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "dev-standards-source-watch/1.0"})
    with urllib.request.urlopen(req, timeout=60) as res:
        return res.read().decode(res.headers.get_content_charset() or "utf-8", errors="replace")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="写しを書き換えずに比べるだけ")
    ap.add_argument("--html-dir", type=Path, help="取得せず <id>.html を読む（試験用）")
    ap.add_argument("--diff-out", type=Path, help="差分（Markdown）をこのファイルに書く")
    args = ap.parse_args()

    sources = json.loads((ROOT / "sources.json").read_text(encoding="utf-8"))["sources"]
    SNAPSHOTS.mkdir(exist_ok=True)
    report: list[str] = []
    errors = 0
    for s in sources:
        snap = SNAPSHOTS / f"{s['id']}.txt"
        try:
            html = (args.html_dir / f"{s['id']}.html").read_text(encoding="utf-8") if args.html_dir else fetch(s["url"])
            new = extract(html, s["start"], s["end"])
        except Exception as e:  # 取得・取り出しの失敗も「見に行くべき変化」として報告する
            errors += 1
            report.append(f"## {s['id']}\n\n{s['url']}\n\n取り出しに失敗しました: `{e}`\n")
            print(f"失敗: {s['id']}: {e}", file=sys.stderr)
            continue
        old = snap.read_text(encoding="utf-8") if snap.exists() else ""
        if new == old:
            print(f"変化なし: {s['id']}")
            continue
        diff = "".join(
            difflib.unified_diff(old.splitlines(True), new.splitlines(True), f"前回 {s['id']}", f"今回 {s['id']}")
        )
        print(f"変化あり: {s['id']}")
        report.append(
            f"## {s['id']}\n\n{s['url']}\n\n使っている所: {s['used_by']}\n\n<details><summary>差分</summary>\n\n"
            f"```diff\n{diff}```\n\n</details>\n"
        )
        if not args.check:
            snap.write_text(new, encoding="utf-8")
    if args.diff_out:
        args.diff_out.write_text("\n".join(report), encoding="utf-8")
    return 1 if report else 0


if __name__ == "__main__":
    sys.exit(main())
