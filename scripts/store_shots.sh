#!/usr/bin/env bash
# App Store screenshots in every language, 6.9-inch (1320x2868), plus a 30 s app preview.
# Run on the Mac after a Debug build is installed on the simulator:
#   scripts/store_shots.sh "Dustbloom 6.9" [langs...]
# Output: store/screenshots/<lang>/NN-name.png, store/preview/preview_en.mp4
set -euo pipefail
DEV="${1:-Dustbloom 6.9}"; shift || true
LANGS=("$@"); [ ${#LANGS[@]} -eq 0 ] && LANGS=(ru en de es fr it pt nl pl sv tr uk id vi th ja ko zh-Hans zh-Hant ar)
APP=game.dustbloom.app
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true

shot() {  # lang name wait args...
  local lang=$1 name=$2 wait=$3; shift 3
  xcrun simctl terminate "$DEV" $APP 2>/dev/null || true
  xcrun simctl launch "$DEV" $APP -bloomLang "$lang" "$@" >/dev/null
  sleep "$wait"
  mkdir -p "$ROOT/store/screenshots/$lang"
  xcrun simctl io "$DEV" screenshot "$ROOT/store/screenshots/$lang/$name.png" >/dev/null
}

for L in "${LANGS[@]}"; do
  echo "== $L"
  rm -f "$ROOT/store/screenshots/$L/"*.png
  shot "$L" 01-intro   7  -bloomShowcase -bloomHoldIntro YES
  shot "$L" 02-island  16 -bloomShowcase
  shot "$L" 03-volcano 16 -bloomShowcase -bloomAll -bloomSpawn 10
  shot "$L" 04-stars   22 -bloomShowcase -bloomAll -bloomSpawn 11 -bloomEvent starfall
  shot "$L" 05-desert  16 -bloomShowcase -bloomAll -bloomSpawn 6
  shot "$L" 06-event   18 -bloomShowcase -bloomAll -bloomEvent fair -bloomPanel event
  shot "$L" 07-build   18 -bloomShowcase -bloomPanel build
  shot "$L" 08-shop    18 -bloomShowcase -bloomPanel shop
done
xcrun simctl terminate "$DEV" $APP 2>/dev/null || true

if [ "${PREVIEW:-1}" = 1 ]; then
  # app preview: demo autopilot fishing on the backwater during the festival, 30 s, 886x1920 with a silent track
  mkdir -p "$ROOT/store/preview"
  xcrun simctl launch "$DEV" $APP -bloomLang en -bloomDemo -bloomShowcase -bloomAll -bloomSpawn 7 -bloomEvent festival >/dev/null
  sleep 9
  xcrun simctl io "$DEV" recordVideo --codec h264 --force /tmp/bloom_raw.mp4 & REC=$!
  sleep 32; kill -INT $REC; wait $REC || true
  xcrun simctl terminate "$DEV" $APP 2>/dev/null || true
  ffmpeg -y -loglevel error -i /tmp/bloom_raw.mp4 -f lavfi -i anullsrc=r=44100:cl=stereo -t 30 \
    -vf "scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,fps=30" \
    -c:v libx264 -profile:v high -pix_fmt yuv420p -b:v 10M -c:a aac -shortest "$ROOT/store/preview/preview_en.mp4"
fi
xcrun simctl status_bar "$DEV" clear || true
xcrun simctl shutdown "$DEV" || true
echo done
