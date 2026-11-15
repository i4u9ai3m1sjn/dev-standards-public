#!/bin/bash
# setup/setup.template.sh に、版と preset のファイルを埋め込んで setup/setup.sh を作る。
#   bash setup/build.sh          … 作り直す
#   bash setup/build.sh --check  … setup.sh が最新か確かめる（CI 用。古ければ exit 1）
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
preset_dir="$root/speckit/presets/project-rules"

files=""
while IFS= read -r f; do
  rel="${f#"$preset_dir"/}"
  files+="  mkdir -p \"\$preset/$(dirname "$rel")\""$'\n'
  files+="  cat >\"\$preset/$rel\" <<'DEV_STANDARDS_EOF'"$'\n'
  files+="$(cat "$f")"$'\n'
  files+="DEV_STANDARDS_EOF"$'\n'
done < <(find "$preset_dir" -type f ! -name README.md | sort)

out="$(
  TEMPLATE="$(cat "$root/setup/setup.template.sh")" \
  DS_VERSION="$(cat "$root/VERSION")" \
  SK_VERSION="$(cat "$root/speckit/VERSION")" \
  PRESET_FILES="${files%$'\n'}" \
  python3 - <<'PY'
import os
s = os.environ["TEMPLATE"]
s = s.replace("__DS_VERSION__", os.environ["DS_VERSION"].strip())
s = s.replace("__SPECKIT_VERSION__", os.environ["SK_VERSION"].strip())
s = s.replace("__PRESET_FILES__", os.environ["PRESET_FILES"])
print(s)
PY
)"

if [[ "${1:-}" == "--check" ]]; then
  if [[ "$out" != "$(cat "$root/setup/setup.sh")" ]]; then
    echo "setup/setup.sh が古いです。bash setup/build.sh を実行してコミットしてください" >&2
    exit 1
  fi
  echo "setup/setup.sh は最新です"
else
  printf '%s\n' "$out" > "$root/setup/setup.sh"
  chmod +x "$root/setup/setup.sh"
  echo "setup/setup.sh を作りました"
fi
