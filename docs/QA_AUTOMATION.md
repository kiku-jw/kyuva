# Local QA API (macOS Debug only)

The separate mobile Debug composition is described at the end of this document;
it does not open a socket or add a network API.

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


## Mobile Debug composition

`KyuvaMobileApp` selects `MobileRuntime.current` before any normal script store,
preferences, purchase store or Watch activation. In a dedicated QA app/container,
set `KYUVA_MOBILE_QA_ID` to a complete UUID. A malformed or empty value terminates
setup; no production library fallback occurs. Hosted XCTest automatically uses a
fresh ID. Release ignores the selector and contains no mobile QA runtime branch.

The UUID maps to `com.kikuai.kyuva.mobile.qa.<lowercaseUUID>` preferences and
`Application Support/KyuvaMobileQA/<lowercaseUUID>/scripts` inside the current
app's storage. Reuse that ID only for the same generated fixture and sequential
restart checks. QA getters read only their own persistent domain. Storage rejects
symlinked/non-directory components and primary/backup leaves that are not regular
single-link files. Access is revalidated before reads and queued writes. Missing
or unsafe QA storage never becomes permission to open a normal library.

The actual runtime exposes `scriptManager`, `userDefaults`,
`makeScrollController(startTimer:)` and `makeSpeechRecognizer()` for native checks
through existing product methods. QA commerce stays disabled even when the Debug
scheme supplies `KYUVA_LOCAL_STOREKIT_TESTING=1`. Speech allocates no audio engine
and start/stop/deinit do not request capture or alter an audio session. Watch is
not activated or bound. Mobile views receive the same runtime and explicit
AppStorage store; import/share, review prompts and external actions are disabled.
No global Codex/macOS setting or new provider permission is needed.

Use generated text, a new UUID and an isolated simulator/container. Check an
edit/save, explicit script selection, pause/resume, normalized progress after
metric changes, then reopen the same script in a second process. Retain original
primary/backup bytes when testing rejected file links or queued writes. Export
evidence before removing only the known UUID directory and preferences domain.
`swift test --scratch-path <task-build-directory> --disable-sandbox` covers shared
core regressions, including revoked access at queued-write time. It does not run
the iOS factory or native views; those require an iOS native runner.

Programmatic model/scroll metrics are not native layout, on-device speech,
Watch communication, iPad support, Store delivery or paid-usefulness acceptance.
The Mac socket API and its sandbox rules above remain unchanged.
