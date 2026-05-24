# Android Source-of-Truth Migration Mapping

Date: 2026-05-20

Android source of truth (read-only):
- `https://github.com/hussien-ibrahem/merge-Hussien-John-Khaled-Android-APK.git`
- Local audit clone: `/tmp/merge-Hussien-John-Khaled-Android-APK`

Project migrated:
- `/Users/johnessam/Documents/New project 5/android`

## Scope rule applied

- iOS native implementation: **KEEP unchanged**.
- Android native BLE/protocol stack: **migrate to source-of-truth repo**.
- Flutter bridge layer: **KEEP/MERGE only for channel routing and envelopes**.

## Mapping

### A) Native Android BLE/protocol source set (bulk 1:1 file mapping)

Rule (applied):

- `OLD FILE`: `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/{baseble,ble,commands,model,ota,protocol,util}/...`
- `NEW FILE`: `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/{baseble,ble,commands,model,ota,protocol,util}/...`
- Decision: **MERGE (replace local with source-of-truth 1:1)**

Validation result after migration:
- same: 97
- changed: 0
- only_old: 0
- only_new: 0

Meaning native Android BLE/protocol directories are fully aligned with source-of-truth.

### B) Bridge layer files (host app integration files)

| OLD FILE | NEW FILE | Decision |
|---|---|---|
| `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/BridgeContract.kt` | n/a (not in source repo) | KEEP |
| `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterEventEmitter.kt` | n/a | KEEP |
| `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterMethodHandler.kt` | n/a | KEEP |
| `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterBridgePlugin.kt` | n/a | KEEP |
| `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/RealAndroidBleBridge.kt` | n/a | MERGE |

`RealAndroidBleBridge.kt` was adapted only to match source-of-truth native APIs (`BleScanner`, `BleConnection`) while keeping MethodChannel/EventChannel contract unchanged.

### C) Demo UI/ViewModel files from source repo (not imported)

| OLD FILE | NEW FILE | Decision |
|---|---|---|
| n/a in Flutter host app | `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/MainActivity.kt` | REMOVE (do not import) |
| n/a | `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/app/MainUiState.kt` | REMOVE |
| n/a | `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/app/MainViewModel.kt` | REMOVE |
| n/a | `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/app/ScooterAppDemo.kt` | REMOVE |
| n/a | `/tmp/merge-Hussien-John-Khaled-Android-APK/app/src/main/java/com/example/scooter_android_demo/ui/...` | REMOVE |

Reason: these are demo app UI files, not required for Flutter host native bridge responsibilities.

## Migration validation

- Android native file sync completed for BLE/protocol stack.
- Build checks passed:
  - `./gradlew :app:compileDebugKotlin`
  - `./gradlew :app:assembleDebug`
- Flutter analysis passed:
  - `flutter analyze`

## Ownership after migration

Android native now owns:
- scan/connect/disconnect
- packet write/read
- parser
- queue pacing
- notify handling
- heartbeat + telemetry
- OTA native stack
- diagnostics
- SDK/custom packet logic

iOS remains unchanged as requested.
