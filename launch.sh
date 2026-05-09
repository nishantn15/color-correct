#!/usr/bin/env bash
# color-correct — local dev server + GitHub Pages publisher.
#
# Usage:
#   bash launch.sh                    # serve current folder, open index.html
#   bash launch.sh probe              # serve, open probe.html
#   bash launch.sh stop               # kill local http server
#   bash launch.sh publish [message]  # sync play files → publish/, commit, push
#
# Layout:
#   .                ← play copy (you edit here)
#   ├── index.html · probe.html · launch.sh · README.md
#   └── publish/                            ← git working tree → GitHub Pages
#       ├── .git/ · index.html · probe.html · launch.sh · README.md

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH="$DIR/publish"
PORT=8000
PAGES_URL="https://nishantn15.github.io/color-correct/"

cmd_stop() {
  fuser -k "${PORT}/tcp" 2>/dev/null || true
  echo "stopped any server on :$PORT"
}

cmd_serve() {
  local PAGE="${1:-index.html}"
  cd "$DIR"
  if curl -sf -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null; then
    echo "Server already running on :$PORT — opening browser…"
  else
    echo "Starting server in $DIR on :$PORT …"
    nohup python3 -m http.server "$PORT" --bind 127.0.0.1 > "$DIR/.http.log" 2>&1 &
    sleep 1
  fi
  local URL="http://127.0.0.1:$PORT/${PAGE}?v=$(date +%s)"
  echo "Open: $URL"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$URL"
  elif command -v am >/dev/null 2>&1; then
    am start -a android.intent.action.VIEW -d "$URL" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 || true
  fi
}

cmd_publish() {
  if [ ! -d "$PUBLISH/.git" ]; then
    echo "ERR: $PUBLISH is not a git working tree." >&2
    echo "First-time setup:" >&2
    echo "  cd $DIR && git clone https://github.com/nishantn15/color-correct.git publish" >&2
    exit 1
  fi
  cp "$DIR/index.html"  "$PUBLISH/index.html"
  cp "$DIR/probe.html"  "$PUBLISH/probe.html"
  cp "$DIR/README.md"   "$PUBLISH/README.md"
  cp "$DIR/launch.sh"   "$PUBLISH/launch.sh"
  cd "$PUBLISH"
  git add -A
  if git diff --cached --quiet; then
    echo "Already up-to-date with publish/. Nothing to push."
    echo "Live: $PAGES_URL"
    return 0
  fi
  local MSG="${1:-Update $(date +%Y-%m-%d\ %H:%M)}"
  git -c commit.gpgsign=false commit -m "$MSG"
  git push
  echo
  echo "Pushed.  Pages will rebuild in ~30 s."
  echo "Live: $PAGES_URL"
}

case "${1:-}" in
  stop)              cmd_stop ;;
  publish)           shift; cmd_publish "${1:-}" ;;
  probe)             cmd_serve probe.html ;;
  ""|serve|index)    cmd_serve index.html ;;
  *.html)            cmd_serve "$1" ;;
  -h|--help|help)    sed -n '2,12p' "$0" ;;
  *)                 echo "Unknown command: $1"; echo "Try: bash launch.sh [serve|probe|publish|stop|help]"; exit 2 ;;
esac
