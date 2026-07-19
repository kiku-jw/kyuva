<p align="center">
  <img src="Kyuva/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="128" height="128" alt="Kyuva Icon">
</p>

<h1 align="center">Kyuva</h1>

<p align="center">
  <strong>macOS teleprompter experiment with a capture-safe camera-side overlay</strong>
</p>

<p align="center">
  <em>Screen-share-safe prompting near the laptop camera, with local voice-follow scrolling</em>
</p>

## About

Kyuva is an open-source macOS teleprompter focused on keeping the script near the camera while staying out of screen shares and recordings.

## Feature Snapshot

- Screen-share-safe overlay for Zoom, Meet, Teams, OBS, and similar tools
- Voice-follow scrolling using on-device speech APIs
- Global hotkeys for scroll speed adjustments
- Local script storage with import and export support
- No account, no analytics, and no required network service

## Build From Source

```bash
git clone https://github.com/kiku-jw/kyuva.git
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

This is a prototype, so expect rough edges and unfinished product paths.

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

Forks are welcome under the project license. Kyuva's narrow focus is camera-side, screen-share-safe prompting on macOS.
