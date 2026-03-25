# VisioLock

VisioLock is a Flutter app for secure image transmission over audio.

The app converts an image into encrypted data, transmits it as an FSK WAV file, and reconstructs the original image on the receiver side.

## Core Workflow

1. Sender picks an image.
2. App derives an encryption key.
3. Image payload is encrypted and FEC-protected.
4. Data is modulated into audio and exported as WAV.
5. Receiver imports WAV, demodulates, decrypts, and reconstructs the image.

## Features

- Sender pipeline: image -> encryption -> FSK audio export
- Receiver pipeline: audio import -> Goertzel-based FSK decoding -> image recovery
- Noise-resilient transmission path with forward error correction
- Android-friendly workflow with file picker and media permission handling

## Tech Stack

- Flutter / Dart
- Reed-Solomon error correction
- FSK modulation and Goertzel demodulation
- Secure local key material support

## Requirements

- Flutter SDK
- Dart SDK (via Flutter)
- Android SDK / Android Studio (for Android builds)

## Run Locally

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk
```

Release APK output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Release Process

This repository includes automated GitHub release publishing via:

- `.github/workflows/release.yml`

When a tag matching `v*` is pushed, GitHub Actions creates a release and attaches the latest APK found in `release/*.apk`.

Typical release steps:

1. Build the app: `flutter build apk`
2. Copy APK to versioned file (example): `release/app-release-v1.0.2.apk`
3. Commit changes
4. Create tag: `git tag -a v1.0.2 -m "VisioLock v1.0.2"`
5. Push: `git push origin main --follow-tags`

## Current Published Artifacts

- `release/app-release-v1.0.0.apk`
- `release/app-release-v1.0.1.apk`

## Notes

- Exported WAV and decoded image files are stored in the app documents directory.
- On Android 13+, media read permissions are requested when selecting image/audio files.
