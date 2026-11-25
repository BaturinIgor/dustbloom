#!/usr/bin/env bash
# iOS build helper. Runs on a Mac with Xcode 15+; spends no GitHub minutes.
#
#   scripts/ios.sh setup        install XcodeGen (Homebrew) and generate the Xcode project
#   scripts/ios.sh test         run unit tests on an iPhone simulator
#   scripts/ios.sh testflight   archive and upload a build to App Store Connect / TestFlight
#
# Needs two values, kept out of git:
#   DEVELOPMENT_TEAM   your Apple Team ID (Xcode > Settings > Accounts, or developer.apple.com > Membership)
#   BUNDLE_ID          app id, default game.dustbloom.app
# Put them in client/.env.local (ignored by git), e.g.
#   DEVELOPMENT_TEAM=ABCDE12345
#   BUNDLE_ID=game.dustbloom.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/client"
BUILD="$ROOT/build/ios"

if [[ -f "$CLIENT/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$CLIENT/.env.local"
  set +a
fi
export BUNDLE_ID="${BUNDLE_ID:-game.dustbloom.app}"
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

generate() {
  if ! command -v xcodegen >/dev/null; then
    echo "Installing XcodeGen with Homebrew..."
    brew install xcodegen
  fi
  (cd "$CLIENT" && xcodegen generate --quiet)
  echo "Generated client/Dustbloom.xcodeproj"
}

simulator() {
  # newest available iPhone simulator
  xcrun simctl list devices available | grep -Eo 'iPhone [^(]+' | sed 's/ *$//' | tail -1
}

cmd="${1:-}"
case "$cmd" in
  setup)
    generate
    ;;
  test)
    generate
    sim="$(simulator)"
    echo "Testing on: $sim"
    xcodebuild test \
      -project "$CLIENT/Dustbloom.xcodeproj" -scheme Dustbloom \
      -destination "platform=iOS Simulator,name=$sim" \
      -quiet
    ;;
  testflight)
    if [[ -z "$DEVELOPMENT_TEAM" ]]; then
      echo "Set DEVELOPMENT_TEAM in client/.env.local first (see the top of this script)." >&2
      exit 1
    fi
    generate
    build_number="$(date +%Y%m%d%H%M)"
    rm -rf "$BUILD" && mkdir -p "$BUILD"
    xcodebuild archive \
      -project "$CLIENT/Dustbloom.xcodeproj" -scheme Dustbloom \
      -destination "generic/platform=iOS" \
      -archivePath "$BUILD/Dustbloom.xcarchive" \
      -allowProvisioningUpdates \
      CURRENT_PROJECT_VERSION="$build_number" \
      -quiet
    sed "s/__TEAM__/$DEVELOPMENT_TEAM/" "$ROOT/scripts/ExportOptions.plist" > "$BUILD/ExportOptions.plist"
    # destination=upload sends the build straight to App Store Connect using
    # the Apple ID signed in to Xcode; no passwords live in this repo.
    xcodebuild -exportArchive \
      -archivePath "$BUILD/Dustbloom.xcarchive" \
      -exportOptionsPlist "$BUILD/ExportOptions.plist" \
      -exportPath "$BUILD/export" \
      -allowProvisioningUpdates
    echo "Uploaded build $build_number. It appears in TestFlight after Apple's processing (usually 5-30 min)."
    ;;
  *)
    sed -n '2,13p' "$0"
    exit 1
    ;;
esac
