# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

This repository is a **native iOS SwiftUI app** (Red Bull Tracker). There is no web server, Node backend, or Docker Compose stack in this repo. The only runnable product is the `RedBullTrackeriOS` Xcode scheme targeting **iOS 17+**.

### Platform requirement (important)

**Full build, lint, test, and run require macOS with Xcode.** Cursor Cloud VMs run Linux and do not provide `xcodebuild`, the iOS Simulator, or Apple SDKs (SwiftUI, Charts, AVFoundation). Cloud agents can validate project structure and bundled data on Linux, but cannot compile or launch the app here.

On macOS, use the commands in `README.md`:

```sh
# Open in Xcode and run RedBullTrackeriOS scheme on iOS 17+ simulator/device

xcodebuild -project RedBullTrackeriOS.xcodeproj \
  -scheme RedBullTrackeriOS \
  -destination 'generic/platform=iOS Simulator' \
  build
```

### Services

| Service | Required? | Notes |
|---|---|---|
| **RedBullTrackeriOS** (Xcode / Simulator) | Yes | Primary app; scheme `RedBullTrackeriOS` |
| **Appwrite** (external BaaS) | Yes for auth/sync E2E | Configure `RedBullTrackeriOS/AppConfig.plist` with real `endpoint`, `projectId`, `databaseId`, `intakeTableId`, `barcodeTableId` |
| **Bundled barcode JSON** | Built-in | `RedBullTrackeriOS/Data/verified-barcodes.json` — works offline, no server |

There is no local backend to start. Appwrite is hosted separately (e.g. Appwrite Cloud at `https://cloud.appwrite.io/v1`).

### Dependencies

- **Swift Package Manager** resolves the Appwrite SDK when opening the project in Xcode (`Package.resolved` is committed).
- No `npm`, `pip`, `Makefile`, or shell bootstrap scripts exist in this repo.
- Linux VMs have no dependency install step beyond cloning the repo.

### Linux-side validation (Cloud Agents)

When macOS/Xcode is unavailable, run structural checks to confirm the workspace is intact:

```sh
python3 - <<'PY'
import json, plistlib
from pathlib import Path

barcodes = json.loads(Path("RedBullTrackeriOS/Data/verified-barcodes.json").read_text())
config = plistlib.load(open("RedBullTrackeriOS/AppConfig.plist", "rb"))
assert len(barcodes) > 0
for k in ("endpoint", "projectId", "databaseId", "intakeTableId", "barcodeTableId"):
    assert k in config
print(f"OK: {len(barcodes)} barcodes, AppConfig keys present")
PY
```

Barcode lookup (core offline feature) can be exercised against the bundled JSON without building the app.

### Lint / tests

The project has **no automated lint or test targets** yet (noted in `README.md` under future improvements). On macOS, rely on Xcode build errors/warnings until test coverage is added.

### Secrets / config

Do not commit real Appwrite credentials. Edit `RedBullTrackeriOS/AppConfig.plist` locally with your project values before running auth/sync flows. The repo ships placeholder values only.
