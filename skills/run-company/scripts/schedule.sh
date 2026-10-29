#!/usr/bin/env bash
# Schedule run.sh for a folder so the harness keeps working when no chat and no app is open.
# macOS: a LaunchAgent com.harness.<folder> (runs while the user is logged in). Linux: a crontab line.
# Usage: schedule.sh <dir> [hours]     install or update, default every 3 hours (RUNNER=claude|codex)
#        schedule.sh --remove <dir>    remove the schedule
#        schedule.sh --list            show harness schedules
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; RUN="$HERE/run.sh"; AGENTS="$HOME/Library/LaunchAgents"
label_for() { echo "com.harness.$(basename "$1" | tr -c 'A-Za-z0-9\n' '-' | tr '[:upper:]' '[:lower:]')"; }
case "${1:-}" in
  --list)
    for p in "$AGENTS"/com.harness.*.plist; do
      [ -f "$p" ] || continue
      secs=$(grep -A1 'StartInterval' "$p" | grep -oE '[0-9]+' | head -1); dir=$(sed -nE 's#.*run\.sh</string><string>([^<]*)</string>.*#\1#p' "$p" | head -1)
      printf '%s  every %sh  %s\n' "$(basename "$p" .plist)" "$(( ${secs:-0} / 3600 ))" "$dir"
    done
    crontab -l 2>/dev/null | grep 'harness run.sh' || true; exit 0 ;;
  --remove)
    DIR="$(cd "${2:?usage: schedule.sh --remove <dir>}" && pwd -P)"; L="$(label_for "$DIR")"
    if [ "$(uname)" = Darwin ]; then launchctl bootout "gui/$(id -u)/$L" 2>/dev/null || true; rm -f "$AGENTS/$L.plist"; echo "removed $L"
    else (crontab -l 2>/dev/null | grep -v "harness run.sh $DIR") | crontab -; echo "removed the cron line for $DIR"; fi
    exit 0 ;;
esac
DIR="$(cd "${1:?usage: schedule.sh <dir> [hours] | --remove <dir> | --list}" && pwd -P)"; HOURS="${2:-3}"
case "$HOURS" in ''|*[!0-9]*|0) echo "hours must be a whole number above 0" >&2; exit 2 ;; esac
[ -f "$DIR/COMPANY.md" ] || [ -f "$DIR/READINESS.md" ] || [ -f "$DIR/PORTFOLIO.md" ] || { echo "no ledger in $DIR (COMPANY.md, READINESS.md or PORTFOLIO.md)" >&2; exit 1; }
RUNNER="${RUNNER:-claude}"; BIN="$(command -v "$RUNNER" || true)"; [ -n "$BIN" ] || { echo "$RUNNER is not on PATH" >&2; exit 1; }
NODE_DIR="$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")"
PATHS="$(dirname "$BIN"):$NODE_DIR:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
mkdir -p "$DIR/.runtime"
if [ "$(uname)" = Darwin ]; then
  L="$(label_for "$DIR")"; P="$AGENTS/$L.plist"; mkdir -p "$AGENTS"
  cat > "$P" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$L</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$RUN</string><string>$DIR</string></array>
  <key>StartInterval</key><integer>$(( HOURS * 3600 ))</integer>
  <key>RunAtLoad</key><false/>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATHS</string><key>RUNNER</key><string>$RUNNER</string><key>HOME</key><string>$HOME</string></dict>
  <key>StandardOutPath</key><string>$DIR/.runtime/launchd.log</string>
  <key>StandardErrorPath</key><string>$DIR/.runtime/launchd.log</string>
</dict></plist>
EOF
  launchctl bootout "gui/$(id -u)/$L" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$P"
  echo "scheduled $L: $RUNNER runs 'continue' in $DIR every ${HOURS}h, log $DIR/.runtime/launchd.log. Remove: schedule.sh --remove $DIR"
else
  line="0 */$HOURS * * * PATH=$PATHS RUNNER=$RUNNER /bin/bash $RUN $DIR >> $DIR/.runtime/launchd.log 2>&1 # harness run.sh $DIR"
  (crontab -l 2>/dev/null | grep -v "harness run.sh $DIR"; echo "$line") | crontab -
  echo "scheduled cron: $line"
fi
