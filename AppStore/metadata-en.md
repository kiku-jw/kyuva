# App Store metadata — English (U.S.)

> Document class: release input. This file owns the first macOS App Store
> listing copy, the prepared 1.1 update, and compliance choices. Update it
> whenever the shipped product or the App Store Connect listing changes.

## App identity

- Public 1.0 name: `Kyuva`
- Prepared 1.1 name: `Kyuva: Teleprompter`
- Bundle ID: `com.kikuai.kyuva`
- SKU: `kyuva-macos-1`
- Public version/build: `1.0 (4)`
- Acceptance candidate/build: `1.1 (7)`
- Publisher: `Mykyta Dudnichenko`
- Primary language: English (U.S.)
- Platform: macOS 13 or later, Apple silicon and Intel
- Primary category: Productivity
- Price: Free
- Initial availability: the 27 European Union storefronts only
- EU Digital Services Act: Non-trader, per owner self-assessment
- Copyright: `2026 Mykyta Dudnichenko`

## URLs

- Support: `https://kiku-jw.github.io/kyuva-landing/support/`
- Privacy policy: `https://kiku-jw.github.io/kyuva-landing/privacy/`
- Marketing: `https://kiku-jw.github.io/kyuva-landing/`

## Distribution links

These are App Store Connect campaign links. They use the English-language Irish
storefront because Kyuva is currently EU-only; the country-neutral URL can
resolve to an unavailable non-EU storefront. Campaign reporting remains inside
Apple and becomes available only after installs from five distinct Apple
Accounts.

- Landing: `https://apps.apple.com/ie/app/apple-store/id6804827338?pt=129302835&ct=kyuva-landing&mt=8`
- GitHub: `https://apps.apple.com/ie/app/apple-store/id6804827338?pt=129302835&ct=github&mt=8`
- KikuAI: `https://apps.apple.com/ie/app/apple-store/id6804827338?pt=129302835&ct=kikuai&mt=8`
- Telegram: `https://apps.apple.com/ie/app/apple-store/id6804827338?pt=129302835&ct=telegram&mt=8`
- LinkedIn: `https://apps.apple.com/ie/app/apple-store/id6804827338?pt=129302835&ct=linkedin&mt=8`

## Product page

### Subtitle

`Private scripts near camera`

### Promotional text

`Keep private scripts beside the camera, pace by speed, words per minute, or finish time, and present without accounts, ads, analytics, or cloud uploads.`

### Description

Kyuva is a free, local-first teleprompter for Mac. It keeps your script close to the camera, helping you speak naturally in calls, recordings, presentations, lessons, product demos, and prepared talks.

Set up a script, place the compact always-on-top prompter where you need it, and choose the pacing that fits your delivery:

• fixed scroll speed;
• words per minute;
• a target finish time.

When your Mac supports on-device recognition for the script language, optional Voice Follow can advance the prompt from your spoken position. Kyuva refuses cloud-only speech recognition instead of uploading audio.

Kyuva also lets you:

• drag and resize the camera-side overlay;
• follow a centered reading cue, progress, and remaining time;
• dim or hide bracketed stage directions;
• mirror the text for beam-splitter teleprompter rigs;
• move the prompter between connected displays;
• control scrolling with the keyboard, trackpad, or mouse;
• import and export scripts.

Kyuva works locally on your Mac. There is no account, subscription, advertising, analytics, or required cloud service. Your scripts and settings stay on your device.

The prompter is a normal macOS window and may appear in screen shares or recordings. Check your preview before presenting.

### Keywords

`autocue,webcam,meeting,presenter,notes,scroll,mirror,offline,overlay,speech,wpm,cue,public speaking`

### Version 1.1 release notes

`Adds a searchable script studio, a calmer camera-side prompt, flexible Fixed/WPM/Duration pacing, and optional on-device Voice Follow for supported languages. Kyuva keeps scripts local and refuses cloud-only speech recognition.`

## Prepared iPhone and Apple Watch product page — not uploaded

### Subtitle

`Speak naturally, stay private`

### Promotional text

`Write, present full-screen, follow your voice on device, and control the pace from Apple Watch—without accounts, ads, analytics, or cloud uploads.`

### Description

Kyuva is a free, local-first teleprompter for iPhone and Apple Watch. It gives your words a calm full-screen reading surface so you can keep your attention on the lens and your audience.

Move from script to prompt in seconds:

• create, search, import, edit, and share scripts;
• choose fixed speed, words per minute, or a target finish time;
• tune typeface, alignment, text size, mirroring, and stage directions;
• follow progress and remaining time without crowding the script;
• pause, reset, or change pace from a paired Apple Watch.

When your iPhone supports on-device recognition for the script language, optional Voice Follow advances from your spoken position. Kyuva refuses cloud-only speech recognition instead of uploading audio.

There is no account, subscription, advertising, analytics, or required cloud service. Your scripts and settings stay on your device.

### Keywords

`autocue,webcam,meeting,presenter,notes,scroll,mirror,offline,speech,wpm,cue,remote,public speaking`

### Version 1.0 release notes

`First iPhone release with local script editing, full-screen prompting, Fixed/WPM/Duration pacing, on-device Voice Follow for supported languages, and paired Apple Watch controls.`

## Privacy and compliance

- App Privacy: select `No, we do not collect data from this app`.
- Tracking: none.
- Advertising: none.
- Accounts: none.
- Network service: none required.
- Encryption export compliance: the app does not use non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`).
- Age rating questionnaire: answer `None` for every content descriptor unless App Store Connect introduces a descriptor that accurately applies. Do not infer the final displayed rating until Apple calculates it.
- Content rights: the app ships no third-party media or licensed content.

## App Review

### Sign-in

- Sign-in required: No
- Demo account: Not applicable

### Contact

Use the account owner's current App Review contact details in App Store Connect. Do not store them in this repository.

### Notes

`Build 7 contains no Mac network entitlement or listener. No account or sign-in is required. On first launch, click Skip or complete the three-page Welcome Guide; Kyuva then opens its searchable script studio. Select the included sample or create a script, adjust pace and reading options in the Prompt inspector, then click Open Prompt. Use the text-bubble menu-bar icon to reopen Kyuva or show and hide the prompt. Optional Voice Follow can be toggled from the prompt, Teleprompter > Toggle Voice Follow, or Control-Option-V. It asks for Microphone and Speech Recognition permission on first use, requires a locale Apple reports as on-device, saves no audio, and refuses cloud-only recognition. StoreKit commerce remains disabled and no product request is made. The prompt is a normal macOS window and may appear in captures.`

## Prepared lifetime Pro product — not created in App Store Connect

This is a provider handoff, not a record of a live product. Keep
`ProEntitlementStore.commerceEnabled = false` until the product, agreements,
compliance answers, sandbox behavior, review metadata, and a fresh owner-approved
release are all verified.

- Type: Non-Consumable
- Reference name: `Kyuva Pro Lifetime`
- Product ID: `com.kikuai.kyuva.pro.lifetime`
- App record: the same multiplatform Kyuva record for macOS and iOS
- Base country or region: Ireland
- Target base price: `EUR 24.99`; select and read back the exact Apple price point
  instead of hard-coding a localized price in the app
- Initial availability: the same 27 EU storefronts as Kyuva; do not activate paid
  availability before the DSA/trader and Paid Apps Agreement decisions
- English display name: `Kyuva Pro Lifetime` (18 of 30 characters)
- English description: `Unlock Voice Follow on Mac and iPhone.` (38 of 45
  characters)
- Review screenshot: capture the in-app Kyuva Pro section only from the exact
  candidate submitted with the first purchase
- Review notes: `One non-consumable purchase unlocks on-device Voice Follow in the macOS and iPhone versions of Kyuva under the same App Store Connect app record. No account, server, cloud service, or subscription is used. Before commerce is enabled, Voice Follow remains an open preview and the app makes no StoreKit product request. On Mac, open Settings > Kyuva Pro and use Teleprompter > Toggle Voice Follow. On iPhone, open a script, tap Present, then tap the waveform button. Speech recognition is allowed only when Apple reports the selected locale as on-device. The seven-day trial is local app state, not an App Store subscription trial.`
- Trial wording: call it a local seven-day trial only after commerce is enabled;
  do not describe it as an Apple-managed subscription trial or promise that it
  survives reinstall or device changes
- Submission gate: Apple requires the first In-App Purchase to be submitted with
  a new app version. Do not create, price, submit, or enable this product without
  a fresh owner-approved paid-release action and exact post-action readback.

## Release

- Version release: Automatically release after approval.
- Current public state: macOS `1.0 (4)` is live after Apple approval on 27 August 2026.
- Processed prior build: macOS `1.1 (6)` was accepted by Apple's uploader on 30 August
  2026 and App Store Connect reports the binary as confirmed and ready to
  submit. Its processed metadata reads back version `1.1`, build `6`, bundle ID
  `com.kikuai.kyuva`, macOS 13, `arm64` + `x86_64`, no non-exempt encryption,
  and only sandbox, microphone, user-selected-file, application/team identifier
  entitlements. It has not been selected for a version, submitted for review,
  or released, and it must not be selected now because build 7 supersedes it.
- Acceptance candidate: macOS `1.1 (7)` and iPhone/Watch `1.0 (5)` are reserved
  in source. They are not uploaded, selected, submitted, approved, or released.
- Candidate screenshots: five English Mac captures at 1440 x 900, five English iPhone 6.9-inch captures at 1320 x 2868, and one English Apple Watch Series 10 capture at 416 x 496 are prepared under `AppStore/Screenshots/`. They are not uploaded. No app preview is prepared.
- App Privacy: published as `Data Not Collected`.
- Distribution: public, free, and verified in exactly the 27 European Union storefronts.
- The reviewer reply and the notes above were sent and persisted before resubmission.
- The owner's 29 August 2026 instruction authorizes preparing and uploading the next build. Submission, metadata publication, and release still require exact readback of the uploaded build and remaining physical acceptance gates.
