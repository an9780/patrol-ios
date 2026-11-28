#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
udid="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
sets=json.load(sys.stdin)["devices"]
print(next(d["udid"] for runtime,devices in sorted(sets.items(), reverse=True)
           if ".iOS-" in runtime for d in devices if d["name"].startswith("iPhone")))
')"
xcodebuild test -project PatrolCheckin.xcodeproj -scheme PatrolCheckin \
  -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO \
  -resultBundlePath "$PWD/dist/Smoke.xcresult" -derivedDataPath "$PWD/build/simulator"
xcrun xcresulttool export attachments --path "$PWD/dist/Smoke.xcresult" --output-path "$PWD/dist/screenshots"

