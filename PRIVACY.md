# Privacy Policy for Kyuva

**Effective Date:** January 5, 2026  
**Last Updated:** March 10, 2026

## Overview

Kyuva ("the App") is a macOS teleprompter project developed by KikuAI. This repository is archived, but the source remains public. This policy explains how the application handles data.

## Data Collection

### What We Collect
**Nothing.** Kyuva does not collect, store, or transmit any personal data.

### Local Data Only
- **Scripts:** Your scripts are stored locally on your Mac in `~/Library/Application Support/Kyuva/`
- **Settings:** Your preferences are stored in macOS UserDefaults
- **No Cloud Sync:** We do not sync any data to external servers

### Audio Processing
- **Voice-Follow Mode:** When enabled, Kyuva uses your Mac's microphone to detect speech
- **100% On-Device:** All audio processing happens locally using Apple's Speech framework
- **Never Transmitted:** Your voice is never recorded, stored, or sent anywhere
- **No Transcription Stored:** We only detect audio levels to control scrolling

## Third-Party Services

Kyuva does not integrate with any third-party analytics, advertising, or tracking services.

The source tree contains some StoreKit-related code from an unreleased commercial path, but the repository does not depend on analytics, advertising, or any cloud backend.

## Data Sharing

We do not share any data with third parties because we do not collect any data.

## Data Security

Since all data remains on your device:
- Your scripts are as secure as your Mac
- No network transmission means no interception risk
- Deleting the app removes all local data

## Children's Privacy

Kyuva does not knowingly collect data from children. Since we collect no data at all, this is not applicable.

## Your Rights

You have complete control over your data:
- **Access:** Your data is in `~/Library/Application Support/Kyuva/`
- **Delete:** Remove the Kyuva folder to delete all data
- **Export:** Use the built-in export feature to save scripts

## Changes to This Policy

If this policy changes, updates will be made in this repository.

## Contact

This project is archived, so active support is not guaranteed.

Repository:
- **GitHub:** https://github.com/KikuAI-Lab/kyuva

---

**Summary:** Kyuva is a privacy-first app. We collect nothing. Everything stays on your Mac.
