#!/bin/bash
# dev-standards __DS_VERSION__ : claude.ai クラウド環境のセットアップスクリプト
# このファイルは setup/build.sh が作る。直接編集せず setup/setup.template.sh を直す。
# Project settings > Environment > Setup script に、このファイルの中身をそのまま貼る。
#
# やること（root で、Claude Code の起動前に1回。結果はスナップショットされる）
#   1. Spec Kit CLI（specify）を版を固定して入れる
#   2. Spec Kit のスキル（/speckit-*）を dev-standards の preset 付きで ~/.claude/skills/ に入れる
#   3. Allure CLI と Playwright のブラウザを先に取ってきておく（失敗しても続ける）
# 失敗しても環境を壊さないよう、各段の失敗は警告だけにして最後は exit 0 にする。

SPECKIT_VERSION="__SPECKIT_VERSION__"
ALLURE_VERSION="3.22.1"
PLAYWRIGHT_VERSION="1.64.1"

log() { echo "[dev-standards setup] $*"; }
export PATH="$HOME/.local/bin:$PATH"

# 1. Spec Kit CLI
if ! command -v uv >/dev/null 2>&1; then
  log "uv を入れます"
  curl -LsSf https://astral.sh/uv/install.sh | sh || log "警告: uv を入れられませんでした"
fi
if command -v uv >/dev/null 2>&1; then
  uv tool install --force "specify-cli @ git+https://github.com/github/spec-kit.git@${SPECKIT_VERSION}" \
    || log "警告: specify-cli ${SPECKIT_VERSION} を入れられませんでした"
fi

# 2. Spec Kit のスキル（preset を当ててから ~/.claude/skills/ へ）
if command -v specify >/dev/null 2>&1; then
  work="$(mktemp -d)"
  preset="$work/preset"
  mkdir -p "$preset"
__PRESET_FILES__
  (
    cd "$work" && mkdir repo && cd repo && git init -q \
      && specify init --here --integration claude --script sh --force \
      && specify preset add --dev "$preset"
  ) >"$work/init.log" 2>&1 || { log "警告: specify init / preset に失敗しました"; tail -20 "$work/init.log"; }
  if ls "$work/repo/.claude/skills"/speckit-* >/dev/null 2>&1; then
    mkdir -p "$HOME/.claude/skills"
    rm -rf "$HOME/.claude/skills"/speckit-*
    cp -R "$work/repo/.claude/skills"/speckit-* "$HOME/.claude/skills/"
    log "Spec Kit のスキルを入れました: $(ls -d "$HOME/.claude/skills"/speckit-* | xargs -n1 basename | tr '\n' ' ')"
  fi
  rm -rf "$work"
fi

# 3. Allure CLI と Playwright のブラウザ（npx のキャッシュに入れておく）
if command -v npx >/dev/null 2>&1; then
  timeout 120 npx -y "allure@${ALLURE_VERSION}" --version >/dev/null 2>&1 \
    || log "警告: allure@${ALLURE_VERSION} を取ってこられませんでした"
  timeout 150 npx -y "playwright@${PLAYWRIGHT_VERSION}" install chromium >/dev/null 2>&1 \
    || log "警告: Playwright ${PLAYWRIGHT_VERSION} のブラウザを入れられませんでした（ネットワーク許可を確認）"
fi

log "完了"
exit 0
