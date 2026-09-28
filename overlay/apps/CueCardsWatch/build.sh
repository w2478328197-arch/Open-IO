#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bundle=${1:-io.openio.example}
[[ "$bundle" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z0-9.-]+$ ]] || exit 2
features=${OPENIO_FEATURES:-cue,run}
[[ ",$features," =~ ,(cue|run), ]] || { echo 'Watch build needs cue and/or run' >&2; exit 2; }
watch_flags=()
[[ ",$features," == *,cue,* ]] && watch_flags+=(OPENIO_CUE)
[[ ",$features," == *,run,* ]] && watch_flags+=(OPENIO_RUN)
printf -v watch_conditions '%s ' "${watch_flags[@]}"
xcodegen generate --spec project.yml
watch_selection=""
[[ ",$features," != *,cue,* ]] || watch_selection=cue
[[ ",$features," != *,run,* ]] || watch_selection="${watch_selection:+$watch_selection,}run"
/usr/bin/plutil -insert OpenIOFeatures -string "$watch_selection" Generated/Info.plist
if [[ ",$features," != *,run,* ]]; then
  for key in WKBackgroundModes NSHealthShareUsageDescription NSHealthUpdateUsageDescription; do
    /usr/libexec/PlistBuddy -c "Delete :$key" Generated/Info.plist
  done
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.healthkit' Generated/Watch.entitlements
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.healthkit.access' Generated/Watch.entitlements
fi
sign_options=(CODE_SIGNING_ALLOWED=NO)
if [[ -n ${OPENIO_DEVELOPMENT_TEAM:-} ]]; then
  [[ "$OPENIO_DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]] || exit 2
  sign_options=(CODE_SIGNING_ALLOWED=YES "DEVELOPMENT_TEAM=$OPENIO_DEVELOPMENT_TEAM" -allowProvisioningUpdates)
fi
xcodebuild -project TurboCueCardsWatch.xcodeproj -scheme CueCardsWatch \
  -destination "${OPENIO_WATCH_DESTINATION:-generic/platform=watchOS}" -derivedDataPath build \
  "TIO_COMPANION_BUNDLE_ID=$bundle" "OPENIO_WATCH_FEATURES=$watch_conditions" "${sign_options[@]}" build
