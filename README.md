<p align="center">
  <img src="Kyuva/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" height="128" alt="Kyuva Icon">
</p>

<h1 align="center">Kyuva</h1>

<p align="center">
  <strong>Archived macOS teleprompter experiment with a capture-safe camera-side overlay</strong>
</p>

<p align="center">
  <em>Screen-share-safe prompting near the laptop camera, with local voice-follow scrolling</em>
</p>

## Project Status

Kyuva is archived and is no longer under active development.

- No App Store release is planned.
- The repository stays public as an open-source reference and portfolio project.
- The main idea worth reusing is the camera-side overlay that stays hidden from screen sharing.
- Support, issue triage, and new feature work are not guaranteed.

## Why This Repository Still Exists

Kyuva is still a useful reference for a narrow macOS presentation workflow:

- a lightweight overlay positioned near the MacBook camera or notch area
- capture exclusion for screen sharing and recording workflows
- local-only voice-follow scrolling without a cloud service
- a small native Swift codebase that is easy to inspect and fork

The broader teleprompter market is already better served by more polished products, so this repository is kept as a clean public artifact rather than an actively competing product.

## Feature Snapshot

- Screen-share-safe overlay for Zoom, Meet, Teams, OBS, and similar tools
- Voice-follow scrolling using on-device speech APIs
- Global hotkeys for scroll speed adjustments
- Local script storage with import and export support
- No account, no analytics, and no required network service

## Build From Source

```bash
git clone https://github.com/KikuAI-Lab/kyuva.git
cd kyuva
open Kyuva.xcodeproj
```

You can also try:

```bash
swift build
```

Requirements:

- macOS 13.0+
- Xcode 15+ or a compatible Swift 5.9 toolchain

This is an archived prototype, so expect rough edges and unfinished product paths.

## Privacy

Kyuva keeps its core behavior local:

- speech processing happens on-device
- scripts are stored on your Mac
- no account is required
- no analytics or tracking are built in

More detail is available in [PRIVACY.md](PRIVACY.md).

## License

This repository is released under [AGPL-3.0](LICENSE).

## Forking

Forks are welcome under the project license. If someone wants to revive Kyuva, the most promising direction is still the narrow wedge it explored well: camera-side, screen-share-safe prompting on macOS.
