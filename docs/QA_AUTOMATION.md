# Local QA API (macOS Debug only)

Use this to exercise the real script store and scroll controller without moving
the user's mouse, sending keyboard events, taking focus, or opening their library.
This is an opt-in test interface, not a public service. Release builds omit the
listener and command handlers. No TCP port, network entitlement, token, or new
dependency is required.

## Build an isolated copy

Run from the repository root with the existing Xcode installation. Use a fresh
identity for each independent experiment; retain the same copy for restart tests.
The QA library contains generated data only. Do not import a personal library.

```sh
export KYUVA_QA_ROOT="$(mktemp -d /Users/nick/Developer/tasks/kyuva-api-XXXXXX)"
export KYUVA_QA_BUNDLE="com.kikuai.kyuva.qa.api.$(uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]')"
python3 - <<'PY'
import os, pathlib, plistlib, pwd
root = pathlib.Path(os.environ['KYUVA_QA_ROOT'])
bundle = os.environ['KYUVA_QA_BUNDLE']
home = pathlib.Path(pwd.getpwuid(os.getuid()).pw_dir)
container = home / 'Library/Containers' / bundle / 'Data'
info = plistlib.loads(pathlib.Path('Kyuva/Resources/Info.plist').read_bytes())
info['KyuvaAutomationEnabled'] = True
info['KyuvaQAStorageDirectory'] = str(container / 'tmp/KyuvaAutomation/scripts')
(root / 'Info.plist').write_bytes(plistlib.dumps(info))
(root / 'socket-path').write_text(str(container / 'tmp/ka/a.sock'))
PY
xcodebuild -project Kyuva.xcodeproj -scheme Kyuva -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$KYUVA_QA_ROOT/derived" \
  -jobs 2 "INFOPLIST_FILE=$KYUVA_QA_ROOT/Info.plist" \
  "PRODUCT_BUNDLE_IDENTIFIER=$KYUVA_QA_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO ENABLE_DEBUG_DYLIB=NO build
export KYUVA_QA_APP="$KYUVA_QA_ROOT/derived/Build/Products/Debug/Kyuva.app"
codesign --force --sign - --entitlements Kyuva/Resources/Kyuva.entitlements "$KYUVA_QA_APP"
codesign --verify --strict --deep "$KYUVA_QA_APP"
open -g -j -n "$KYUVA_QA_APP"
export KYUVA_QA_SOCKET="$(cat "$KYUVA_QA_ROOT/socket-path")"
```

Only `com.kikuai.kyuva.qa.api.<suffix>` with storage exactly in that bundle's
sandbox `Data/tmp/KyuvaAutomation/scripts` is accepted. Explicit invalid opt-in
configuration stops before model/storage initialization; it never falls back to
the ordinary library. Symlink components and primary/backup files are rejected.
Do not override `HOME` or `CFFIXED_USER_HOME`.

## Read state and run commands

```sh
curl --fail-with-body --max-time 5 --unix-socket "$KYUVA_QA_SOCKET" \
  http://localhost/v1/state
curl --fail-with-body --max-time 5 --unix-socket "$KYUVA_QA_SOCKET" \
  -H 'Content-Type: application/json' \
  -d '{"command":"createScript","name":"Rehearsal","text":"Generated rehearsal text.\nSecond paragraph."}' \
  http://localhost/v1/commands
```

`GET /v1/state` is read-only. It reports save/load status, selected UUID, exact
script names/text and actual prompt visibility, pause and scroll offset. Above
512 KiB it returns `state_limited: true`, script count and save/load status,
explicitly omitting the full library. This does not mean the library is empty.

`POST /v1/commands` accepts exactly these JSON keys:

| Command | Additional keys | Outcome |
| --- | --- | --- |
| `createScript` | `name`, `text` | Creates and selects through `ScriptManager`; save can still be pending. Name limit 512 UTF-8 bytes, text 60,000. |
| `selectScript` | `id` | Selects an existing UUID. |
| `save` | None | Waits for actual disk writes; failure is HTTP 409. |
| `showPrompt` | None | Shows the real overlay without activation or accepting mouse input. |
| `hidePrompt` | None | Hides the overlay. |
| `start` | None | Resumes the actual scroll timer; requires a visible prompt. |
| `pause` | None | Manually pauses the actual controller. |
| `quit` | None | Flushes storage, replies, then requests normal app termination. A save failure keeps the app open. |

Normal command replies are bounded acknowledgements with `selected_script_id`.
HTTP 200 alone does not prove the final result: read state after the action and
independently inspect the generated library after `save`. A transport timeout
can occur after a mutation; read back before retrying `createScript` to avoid
duplicates. No automatic mutation retries or idempotency guarantee is supplied.

The socket is owned by the current UID, mode 0600 in a mode-0700 directory, and
checks the peer UID. Other processes running as that user are inside the trust
boundary; this is not protection from a malicious same-user process. Requests
have bounded headers/body/timeouts, one request per connection and no pipelining.
Script text is not logged by the listener.

## Acceptance and teardown

Use a generated multilingual rehearsal long enough to scroll. Create → save →
read exact text/UUID → show → start → observe increasing offset → pause → observe
stable offset → hide → quit. Relaunch the same app with `open -g -j -n` and verify
the same UUID/name/text and the generated `scripts.json`, then quit through the
API again. Normal termination removes the owned socket.

For failure coverage, use only this generated library: preserve its exact bytes,
replace either library leaf with a symlink to a generated sentinel, verify save
returns 409 and leaves the sentinel/original untouched, restore the exact leaf,
then verify save succeeds. Never perform this experiment on a personal library.

Run protocol and storage regression tests with `swift test`. A stale socket after
a crash blocks startup rather than being deleted automatically. Investigate its
exact owner/process before any manual removal; do not broadly delete containers.
Rollback is to stop the QA copy and use a normal build without the opt-in keys.
Keep the generated QA library if retaining restart evidence.

This route proves model, native-process and persistence behavior. It does not
prove text readability, editor typing, speech recognition, physical-device
behavior, Store upgrades, restored personal data, demand or paid readiness.
