# AI Handoff Guide — cardoO Scooter SDK Test App

**Purpose**: a self-contained briefing for a fresh AI session. Paste this (or `@`-reference it) at the start of a new chat so the assistant can pick up the project without rediscovering its conventions.

---

## 1. Project at a glance

- **What this is**: an Android Kotlin test harness that talks to **cardoO scooters over BLE** using the bundled **TCBSDK.jar** (Tao Chen controller protocol v1.1.29).
- **One screen, one big scroll**: `MainActivity` inflates `activity_main.xml`. Each feature shows up as a panel inside `featuresSection`, added at the bottom as it's wired.
- **Single BleManager**: `app/src/main/java/com/cardoo/scooter/ble/BleManager.kt` is the BLE entry point. All TX/RX flows through here.
- **Target hardware**: cardoO Scooter **v3 (S3)**. Older revisions (S1 / S2) may differ — when in doubt, ask which version the user is testing.
- **Repo**: `hussien-ibrahem/scooter-sdk-hussien`. Branch we work on: **`codex/setCruiseControl`**.

---

## 2. Critical workflow rules — don't break these

1. **Work directly in the main project path** `/Users/dev.husseincardoo.co/Desktop/PC/Projects/cardoO App/SDK/Scooter/scooter app v3/` — *not* the `.claude/worktrees/...` worktree. The user's Android Studio is open on this path. Edits made elsewhere are invisible.
2. **NEVER commit a feature until the user explicitly approves it as working on the scooter.** The user tests on a physical bike — leave changes uncommitted while iterating. Only commit after a "perfect" / "it works" / "push" message.
3. **Exception — UNTESTED pushes**: the user sometimes asks to push code that hasn't been tested yet (e.g. for batch features). Then the commit title must contain the literal word `UNTESTED` and the message must spell out what needs verifying.
4. **Default `git` may hit Xcode license issues** on this Mac. Use the Command Line Tools git path instead: `/Library/Developer/CommandLineTools/usr/bin/git -C "/Users/dev.husseincardoo.co/Desktop/PC/Projects/cardoO App/SDK/Scooter/scooter app v3" ...`
5. **Push target**: `git push origin codex/setCruiseControl`. The user fast-forwards this from their main project; no other branches are in play.
6. **Don't auto-commit doc / sheet changes** unless the user has clearly approved them. Treat sheet status updates as a record of a verified finding.

---

## 3. Sources of truth (in order of authority)

1. **`app/libs/TCBSDK.jar`** — the actual SDK we ship against. Anything we say about "the SDK" must be backed by a `javap` dump of this jar (see §6).
2. **`TaoTao_Controller_Protocol_V1.1.29_EN.docx`** — the protocol spec. Tells us frame structure, function codes, byte layouts. Sometimes ambiguous on encoding (ASCII vs numeric digits, big- vs little-endian) — when ambiguous, default to ASCII / big-endian.
3. **`docs/features/cardoO Scooter SDK Features (Hussien).xlsx`** — the canonical task list. 50 rows of features. Column 5 names the Android SDK method (or "Manual frame ..." when there's a gap). Columns 7 / 8 / 9 = S1 / S2 / S3 verification status. **Feature `#N` is at spreadsheet row `N + 1`** (header is row 1).
4. **`app/docs/customized-frames.md`** — every place we hand-build bytes instead of using an SDK builder, with the reason. Read this before adding any new manual frame.

---

## 4. New feature implementation playbook

Follow these steps in order — every approved feature in the repo's history has gone through this loop.

### Step 1 — Look up the feature

Find the row in `docs/features/cardoO Scooter SDK Features (Hussien).xlsx`. Note:
- The function code (e.g. `0x000B`).
- The Android column — either a `TCBxxCMD.someMethod(...)` reference (SDK has a builder) or `Manual frame ...` (no SDK builder).
- The S3 column — `✓ Working`, `✗ Not supported`, or blank.

### Step 2 — Read the protocol doc for that function code

```python
# Quick way to grep a function code's spec
python3 << 'PY'
from docx import Document
doc = Document('TaoTao_Controller_Protocol_V1.1.29_EN.docx')
# walk body, find the section for the function code,
# print master-side + slave-side frame layouts.
PY
```

You want: request length, request data layout, response length, response data layout, and any "type" / "selector" byte in byte5.

### Step 3 — Confirm the SDK surface

Even if the sheet says there's an SDK builder, double-check it exists with the signature you expect:

```bash
# (Extract once: unzip app/libs/TCBSDK.jar -d /tmp/tcbsdk)
javap -p /tmp/tcbsdk/com/example/tcblecomminucation/cmd/TCB0BCMD.class
# Returns the public byte[] methods + their parameter types.
```

If the SDK has the builder, great — use it. If not (or its parameters don't cover your case), it's a manual frame.

### Step 4 — Wire in `BleManager.kt`

**SDK path (preferred)**: one-line chained call.

```kotlin
fun readMeterVersion() =
    TCB11CMD.readMeterVersion().send("TX read meter version")
```

The `.send(label)` extension lives near `writeRaw` at the bottom of the file. It handles the null-check + transport. **Do not add `writeRaw(...)` calls in new SDK-path functions** — they undo the refactor.

**Manual path (only when SDK has no builder)**:

```kotlin
fun readSerialNumber() {
    val payload = "5a011d0000"
    val bytes = TCBHelper.hexStringToBytes(payload + TCBHelper.crc16(payload))
    if (bytes == null) { post { listener?.onLog("Serial command not generated.") }; return }
    writeRaw(bytes, label = "TX read serial number")
}
```

Use `writeRaw` directly here — it's expected for manual frames. Document the new manual frame in `app/docs/customized-frames.md`.

**Response handling**: add a `handleXxx(data)` parser BEFORE `TCBManager.convertToModel(data)` in `handleNotification`, OR (if the SDK parses the response into a `TCBxxModel`) add a `when (model)` branch with a `handleXxx(model)` method.

**v3 mirror framing**: v3 firmware often replies with `byte2 = function code, byte3 = function code` (mirrored), `byte4 = single-byte length` — different from the protocol doc which says `byte3 = 0x00, byte4 = length high byte` etc. Robust decoders should accept both:

```kotlin
val payloadLength = if (byte3 == functionCode) byte4 else (byte3 shl 8) or byte4
```

### Step 5 — Add UI

Append a new panel to `app/src/main/res/layout/activity_main.xml` at the **bottom of `featuresSection`** (after the most recent feature). Match the existing styling — copy a similar panel and tweak labels.

Section panels follow this pattern:

```xml
<LinearLayout android:background="@drawable/bg_panel" ...>
    <TextView android:text="@string/feature_title" .../>
    <!-- One or more buttons / inputs -->
</LinearLayout>
```

Drawables in use: `bg_button_primary` (black), `bg_button_secondary` (lime/white), `bg_button_danger` (red — only for destructive actions).

### Step 6 — Wire `MainActivity.kt`

Two places:

1. **`setupActions()`** — add the click listener(s) for the new view ID(s).
2. **`setFeatureActionsEnabled(enabled: Boolean)`** — toggle the new view IDs on connect/disconnect.

Add destructive operations behind an `AlertDialog.Builder` two-tap confirm (see `confirmFactoryReset` / `confirmChangeLockPassword` for the pattern).

### Step 7 — Strings

Add labels to `app/src/main/res/values/strings.xml`. Keep formatters consistent — `%1$d` for numeric values, `%1$s` for strings.

### Step 8 — Hand off to the user for testing

Tell them: sync Gradle, build & install, scroll to the new section, do the test flow. Spell out the expected log lines for both a successful response and a silent / error case.

### Step 9 — Commit only after approval

Once the user confirms it works:

```bash
GIT=/Library/Developer/CommandLineTools/usr/bin/git
$GIT -C "$ROOT" add app/src/main/java/com/cardoo/scooter/MainActivity.kt \
                   app/src/main/java/com/cardoo/scooter/ble/BleManager.kt \
                   app/src/main/res/layout/activity_main.xml \
                   app/src/main/res/values/strings.xml
$GIT -C "$ROOT" commit -m "$(cat <<'EOF'
Add <feature> read

<one-paragraph description>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
$GIT -C "$ROOT" push origin codex/setCruiseControl
```

Match the existing commit-style: short imperative title, body that explains *why* (one paragraph).

---

## 5. When a feature doesn't work on v3

Several protocol functions are **silent** on v3 firmware — the BLE write is accepted, but no notification ever comes back. Established cases:

| Function | Method | Status |
|---|---|---|
| `0x000C` Battery Voltage Detail | reverted entirely | not supported on S3 |
| `0x0031` Riding Time | not exposed in UI | issue #4 |
| `0x0006` Auto Power-Off | kept in UI, read silent / set unverifiable | issue #5 |
| `0x00E0`–`E2` OTA | UI present, doesn't progress | issue #6 |
| `0x0005` Gear Max Speed Write + profiles | reads OK, writes don't take effect | issue #7 |
| `0x00A4`/`A7`/`A8`/`A9` Password family | all silent | issue #8 |

The user's policy:

1. **Confirm the silence** — check the logcat for `onCharacteristicChanged` lines. If the only `data:5ab301...` notifications you see are the heartbeat, the function is genuinely silent.
2. **Decide**: revert the entire feature, or keep the UI with a warning. The user has chosen both for different features — ask which they prefer.
3. **Mark the sheet**: update column 9 (S3 status) of the relevant row via openpyxl:

   ```python
   from openpyxl import load_workbook
   wb = load_workbook('docs/features/cardoO Scooter SDK Features (Hussien).xlsx')
   ws = wb.active
   for row in ws.iter_rows(min_row=2):
       if row[0].value == FEATURE_NUM:
           ws.cell(row=row[0].row, column=9).value = '✗ Not working on v3 (issue #X)'
           break
   wb.save(wb.path)
   ```

4. **File a GitHub issue** (see §7). Required labels: `bug`, `firmware`, `scooter-v3`.
5. **Commit the sheet update** with a one-paragraph note about what was verified.

---

## 6. Useful local commands

### Inspect the SDK

```bash
# One-time extract
unzip /Users/dev.husseincardoo.co/Desktop/PC/Projects/cardoO\ App/SDK/Scooter/scooter\ app\ v3/app/libs/TCBSDK.jar \
      -d /tmp/tcbsdk

# List all CMD class public byte[] builders
for cls in /tmp/tcbsdk/com/example/tcblecomminucation/cmd/TCB*.class; do
  javap -p "$cls" | grep "public.*\[\]"
done

# Disassemble a builder to see the hex payload it constructs
javap -c -p /tmp/tcbsdk/com/example/tcblecomminucation/cmd/TCB0BCMD.class | head -40

# Check which models TCBManager.convertToModel parses
javap -c -p /tmp/tcbsdk/com/example/tcblecomminucation/TCBManager.class | \
  grep -E "TCB.*Model|setReady|setData" | head -30
```

### Read the protocol doc

```bash
pip3 install python-docx --quiet  # one-time

# Search for a function code section
python3 << 'PY'
from docx import Document
doc = Document('TaoTao_Controller_Protocol_V1.1.29_EN.docx')
# walk doc.element.body — paragraphs and tables in order
PY
```

### Read / write the feature spreadsheet

```bash
pip3 install openpyxl --quiet  # one-time

python3 << 'PY'
from openpyxl import load_workbook
wb = load_workbook('docs/features/cardoO Scooter SDK Features (Hussien).xlsx', data_only=True)
ws = wb.active
for row in ws.iter_rows(values_only=True):
    print(row)
PY
```

### Git (the Xcode-license-safe way)

```bash
GIT=/Library/Developer/CommandLineTools/usr/bin/git
ROOT="/Users/dev.husseincardoo.co/Desktop/PC/Projects/cardoO App/SDK/Scooter/scooter app v3"
$GIT -C "$ROOT" status --short
$GIT -C "$ROOT" log --oneline -5
$GIT -C "$ROOT" add <files>
$GIT -C "$ROOT" commit -m "..."
$GIT -C "$ROOT" push origin codex/setCruiseControl
```

---

## 7. Filing a GitHub issue

The repo has the user's credentials cached in git credential helper. Pull the token and call the REST API directly — `gh` CLI is also installed but unauthenticated.

```bash
TOKEN=$(printf "url=https://github.com\n\n" | git credential fill 2>/dev/null \
        | awk -F= '/^password=/ {print $2}')

# Required labels for any scooter-v3 issue: bug, firmware, scooter-v3
python3 <<'PY' > /tmp/issue.json
import json
print(json.dumps({
  "title": "...",
  "body": """...markdown body...""",
  "labels": ["bug", "firmware", "scooter-v3"],
}))
PY

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d @/tmp/issue.json \
  https://api.github.com/repos/hussien-ibrahem/scooter-sdk-hussien/issues
```

The three labels (`bug`, `firmware`, `scooter-v3`) already exist in the repo. **All v3-related issues should carry all three.** If you create a new label, use a soft color and a one-line description.

Existing open issues to reference (state as of last update):

| # | Title |
|---|---|
| 1 | Charging state cannot be continuously tracked after scooter powers down |
| 2 | Running Effect ambient light mode is not working from the SDK |
| 3 | Internal battery temperature always reports 0 C |
| 4 | Riding Time (0x0031) returns no response on v3 firmware |
| 5 | Auto Power-Off (0x0006) read silent on v3, set unverifiable |
| 6 | OTA firmware update (Controller / Meter) does not complete on v3 firmware |
| 7 | Gear Max Speed write + Sport/Eco/Custom profiles do not take effect on v3 firmware |
| 8 | Password / Security Utilities (0x00A4 / 0x00A7 / 0x00A8 / 0x00A9) all silent on v3 firmware |

---

## 8. Common gotchas (lessons learned the hard way)

1. **Kotlin/Java boolean property names**: when a Java class has `boolean foo` with `isFoo()/setFoo()`, the Kotlin property is `isFoo` (not `foo`). Trying `instance.foo = true` binds to the package-private field and fails to compile. Use `instance.isFoo = true`.
2. **Signed int16 parsing**: `byte.toInt()` in Kotlin sign-extends. For unsigned values, always `... and 0xFF` first. For signed big-endian int16: `(hi.toInt() shl 8) or (lo.toInt() and 0xFF)` — `hi.toInt()` keeps the sign, `lo and 0xFF` strips it.
3. **The "max speed" field**: v3 firmware heavily smooths it — slow climb to the actual peak rather than instant. Not a parser bug.
4. **Heartbeat is on `0x0001`**: the lock-with-password response also uses `0x0001` per the protocol doc, so a lock-state change shows up as the next heartbeat reflecting the new state — not as a separate response.
5. **The `+6 offset` on `writeGearMaxSpeed`**: the SDK silently adds 6 to whatever speed you pass. Reading back via `readGearMaxSpeed` shows the actual stored value (which may be `requested + 6`).
6. **`writeRaw` exists for two reasons**: (a) the `.send` extension calls it internally as the central BLE transport, and (b) manual-frame functions call it directly because they construct payloads with non-SDK code. **Do not add new `writeRaw` calls in SDK-path functions.**
7. **OTA `TCBE0Model` ack**: the SDK has no public method for ack'ing the E0 (ready) response; we seed a synthetic `TCBE1Model(index=0, isDataReceivingStatus=true)` to kick the packet sequence. If OTA stalls right after the ready ack, the seed approach may be wrong — try reflection or contact the vendor.
8. **Bootloader OTA (`0x00D0`/`D1`/`D2`)** is **disabled** intentionally. The protocol doc says it's not implemented by the manufacturer. Don't enable it until vendor-signed binaries + a JTAG recovery setup are in place.
9. **Password byte encoding** is assumed ASCII (`'0'` = `0x30`). If `000000` is rejected on test, try raw numeric (`0x00`) — the protocol doc is ambiguous.

---

## 9. File map cheat-sheet

```
app/
├── docs/                              ← this folder
│   ├── ai-handoff.md                  ← you are here
│   └── customized-frames.md           ← list of every manual-frame function and why
├── libs/
│   └── TCBSDK.jar                     ← the SDK
├── src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/cardoo/scooter/
│   │   ├── MainActivity.kt            ← view binding + click listeners + dialogs
│   │   ├── CardooScooterApp.kt
│   │   ├── ble/
│   │   │   ├── BleManager.kt          ← all BLE work; SDK builders + .send extension
│   │   │   └── BleModels.kt           ← data classes + BleEventListener + OtaState
│   │   ├── baseble/                   ← ViseBle wrapper (do not modify)
│   │   └── utils/                     ← ByteUtils helpers
│   └── res/
│       ├── layout/activity_main.xml   ← all panels for all features
│       ├── values/strings.xml
│       └── drawable/bg_button_*.xml   ← primary / secondary / danger
docs/
├── features/                          ← canonical feature list (xlsx)
├── *.logcat                           ← user-shared adb logcat dumps
TaoTao_Controller_Protocol_V1.1.29_EN.docx
TaoTao_Controller_Protocol_V1.1.29.pdf (Chinese)
```

---

## 10. Quick paste — minimal context for a new session

> "We're working on the cardoO Scooter Android test harness in `~/Desktop/PC/Projects/cardoO App/SDK/Scooter/scooter app v3/`. Branch: `codex/setCruiseControl`. The full handoff doc is in `app/docs/ai-handoff.md` and the customization catalog is in `app/docs/customized-frames.md`. Read both before suggesting changes. Workflow: implement → I test on a real scooter → only commit after I approve. Use `/Library/Developer/CommandLineTools/usr/bin/git` for any git operation."

---

_Generated as a companion to `customized-frames.md` so future sessions can ramp up without re-deriving the conventions._
