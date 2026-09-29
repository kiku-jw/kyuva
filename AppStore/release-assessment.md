# Kyuva App Store ASO and narrow release assessment

> Document class: prepared release handoff. Owner: `kiku-jw/kyuva` Issue #2.
> Source state: `a80956c` (`main` as inspected on 2026-09-30). Update this
> document when the candidate commit, App Store Connect readback, owner
> acceptance, or physical-device receipt changes. It records no provider
> mutation and does not authorize upload or submission.

## Decision snapshot

- **Mac-only 1.1:** ASO copy is draft-prepared, but the update is not
  submission-ready. Root's follow-up owns any future Store save.
  The exact candidate still needs owner hands-on acceptance and an action-time
  App Store Connect upload/readback. If those gates pass, the Mac update is the
  smallest release path.
- **iPhone/Watch:** not Store-ready. Source build `1.0 (5)` exists and CI is
  green, but the mobile candidate is not uploaded and physical Voice Follow and
  Watch behavior remain unverified. No mobile App Store availability is claimed.
- **App implementation:** no additional code change is necessary for this ASO
  slice. The latest bounded product improvement is already in `a80956c`:
  prompt progress survives rotation/resizing, onboarding follows the current
  library-to-prompt flow, and capture copy remains honest. Adding a new feature
  before owner acceptance would widen scope without reducing a release blocker.

## Store and source truth

| Surface | Version/build | Current state | What it proves |
| --- | --- | --- | --- |
| macOS public | `1.0 (4)` | Live in the Mac App Store, free, EU-27 storefronts | Public Mac listing only; no Voice Follow or purchase path |
| macOS prior candidate | `1.1 (6)` | Processed by Apple, Ready to Submit, unselected and unsubmitted | A historical processed binary exists in App Store Connect; build 7 supersedes it |
| macOS acceptance candidate | `1.1 (7)` | Source-only at `a80956c`; not uploaded, selected, submitted, approved, or released | Candidate behavior, screenshots, and metadata can be reviewed locally |
| iPhone + Watch candidate | `1.0 (5)` | Source-only; not uploaded or publicly available | Local/CI build surface only; no Store claim |

The App Store record is `6804827338` (`com.kikuai.kyuva`). Issue #2's current
handoff is the authority for the provider and device state above. The repository
contains English screenshots only; no Russian screenshots or Russian source
localization are prepared.

## ASO copy acceptance

The copy pack is split so live Mac 1.0 text cannot accidentally inherit
candidate-only claims:

- [`metadata-en.md`](metadata-en.md) contains live 1.0 copy and unsubmitted Mac
  1.1 copy.
- [`metadata-ru.md`](metadata-ru.md) contains a Russian translation draft for
  the same two Mac surfaces. It is not an enabled app localization.
- Both candidate titles make the intent explicit without naming a competitor:
  `Kyuva: Teleprompter` and `Kyuva: Телесуфлёр`.
- Candidate descriptions mention Voice Follow only as optional Apple on-device
  recognition for supported languages. They do not promise capture exclusion;
  both languages state that the normal macOS prompt may appear in shares or
  recordings.
- Candidate keyword sets contain no competitor name, duplicate token, or
  `teleprompter` duplicate (the title already carries the generic intent).

The Xcode project has `knownRegions = (en, Base)` and the screenshot pack has
`locales: ["en"]`; Russian copy must remain a draft until UI, screenshots, and
review notes are localized together.

All limits below are checked against the literal copy in the two metadata files;
keyword bytes are included because App Store keyword fields are byte-limited.

| Surface | Title | Subtitle | Keywords | Promotional text |
| --- | ---: | ---: | ---: | ---: |
| English live 1.0 | 5/30 chars | 27/30 chars | 83/100 bytes | 152/170 chars |
| English candidate 1.1 | 19/30 chars | 26/30 chars | 94/100 bytes | 143/170 chars |
| Russian live 1.0 draft | 5/30 chars | 22/30 chars (41 bytes) | 75/100 bytes | 110/170 chars |
| Russian candidate 1.1 draft | 17/30 chars (27 bytes) | 28/30 chars (52 bytes) | 98/100 bytes | 122/170 chars |

## Candidate receipt and exact commands

The following is the inherited receipt recorded in Issue #2 and the repository
CI workflow for source `a80956c`. It is not a fresh local build from this ASO
pass; this task intentionally did not build, sign, upload, or use a device.

### Tests and package build

```text
swift test --disable-sandbox                 # 55/55 passed at a80956c
swift build -c release --disable-sandbox     # passed at a80956c
```

### macOS Release builds (CI, one per architecture)

```text
xcodebuild -project Kyuva.xcodeproj -scheme Kyuva -configuration Release \
  -destination 'platform=macOS,arch=arm64' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath "$RUNNER_TEMP/KyuvaDerivedData" build

xcodebuild -project Kyuva.xcodeproj -scheme Kyuva -configuration Release \
  -destination 'platform=macOS,arch=x86_64' ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath "$RUNNER_TEMP/KyuvaDerivedData" build
```

CI then validates the Mac bundle as `com.kikuai.kyuva`, version `1.1`, build
`7`, macOS `13.0+`, both architectures, privacy manifests, speech usage
descriptions, no Bonjour/local-network keys, no network entitlements/listener
markers, no Release StoreKit test payload, and on-device-only speech guards.

### iPhone and Watch Release builds (CI)

```text
xcodebuild -project Kyuva.xcodeproj -scheme 'Kyuva iOS' -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$RUNNER_TEMP/KyuvaMobileDerivedData" build

xcodebuild -project Kyuva.xcodeproj -scheme 'Kyuva Watch App' -configuration Release \
  -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$RUNNER_TEMP/KyuvaWatchDerivedData" build
```

CI validates mobile build `5`, embedded Watch bundle identity/companion
relationship, privacy manifests, absence of Mac-remote/network markers, and
absence of Release StoreKit test payloads. Issue #2 records CI run
`34662596457` as green for Mac arm64, Mac x86_64, and iPhone/Watch.

## Release blockers and readiness

### Mac 1.1 (7)

**Conditional upload readiness, not release readiness.** The remaining gates
are:

1. Nick's hands-on Mac library/editor/prompt/shortcut acceptance on the exact
   candidate, including direct Voice Follow read-aloud behavior.
2. A fresh capture-preview check in the real meeting/recording paths that will
   be claimed; the normal prompt window must not be described as invisible.
3. Owner-authorized App Store Connect upload of build 7, followed by exact
   processing/readback, metadata/screenshot persistence, version selection,
   review submission, and post-action state verification.
4. Final review of English copy and an explicit decision on the Russian draft;
   the current app has no Russian UI or screenshots.

Until those steps happen, the accurate wording is **candidate prepared** rather
than ready to submit, approved, or released. Build 6 must not be selected now;
build 7 supersedes it.

### iPhone/Watch 1.0 (5)

**Not ready for Store upload.** The physical iPhone Voice Follow read-aloud and
physical Watch behavior are unverified; the Watch is unavailable to CoreDevice
in the latest handoff. Mobile build 5 is not uploaded, selected, submitted,
approved, or publicly available. Keep mobile metadata and screenshots marked as
prepared/source-only until those receipts exist.

## Archived-build answer

The repository has **historical documentation receipts**, but no archived build
artifact:

- `.agent/tasks/issue-2-macos-network-entitlement/evidence.md` records that a
  universal Mac Release build/archive/export passed for public build 4.
- `.agent/tasks/issue-2-apple-suite/evidence.md` retains historical upload and
  Store readback logs, but those are text/screenshot evidence, not an
  `.xcarchive`.
- `git ls-tree` at `a80956c` contains no tracked `.xcarchive`, `.app`, `.ipa`,
  `.pkg`, or `.dmg` artifact. The current candidate's signed Mac app was
  reported installed/running in the Issue handoff, not archived in this clone.
- `README.md` explicitly says the historical `v1.0.0` GitHub-release binary is a
  development build, not a verified App Store distribution artifact.

Therefore: **archive/build evidence exists in repo docs; an archived binary does
not exist in the repo.** The processed Mac 1.1 (6) binary exists only in the
App Store Connect provider state, and candidate 1.1 (7) remains source-only.
