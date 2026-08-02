# Provika

**English** · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md)

**Capture. Package. Verify.**

Provika is an iOS app for capturing photos and videos when the time, place, and integrity of the original matter. It creates portable evidence packages that can be exported and verified offline.

Provika is not limited to traffic reporting. It can be used for incident documentation, inspections, delivery and property records, field work, and other situations where a reviewable capture record is useful.

> Provika provides technical integrity information. It does not replace forensic analysis, determine legal admissibility, or guarantee acceptance by any organization. Follow local laws and respect privacy when recording, exporting, or sharing.

## What Provika Does

1. Captures a photo or video together with time, location when authorized, and device context.
2. Preserves the original media and creates a canonical claim.
3. Calculates SHA-256 digests and signs the package with an ECDSA P-256 key.
4. Stores the signature envelope and verification material with the package.
5. Verifies package integrity independently without relying on the signing Keychain entry.
6. Exports a verified reading copy as a safe ZIP with a multilingual PDF report.

## Core Capabilities

| Area | Capabilities |
| --- | --- |
| Photo and video evidence | Versioned evidence claims, original-media preservation, deterministic package finalization, and validation |
| Integrity | SHA-256 digests, ECDSA P-256 signatures, exported public-key material, and offline verification |
| Camera | Live preview, focus and exposure, flash, zoom controls, 0.5× ultra-wide support, orientation-aware output, and continuous recording |
| Pre-recording | Configurable 0 / 5 / 15 / 30-second pre-record buffer |
| Visible context | Optional date, time, GPS, and app/device overlays rendered into video frames |
| Export | Verified ZIP export and human-readable PDF reports in five languages |
| Gallery | Browse, filter, play, inspect verification state, select, share, and delete local records |
| Fast capture | Control Center and Lock Screen entry points, App Intents, and an ExtensionKit locked-camera capture extension |
| Data safety | Legacy-recording migration, immutable-original policy, safe filenames, symlink rejection, and atomic staging |
| Regional readiness | A single global offline Evidence Core with claims and UI support for China mainland; no China-only evidence fork |

## Evidence Package

A finalized v2 package contains the original media and machine-readable verification records such as:

```text
EvidencePackage/
  <original media>
  claim.json
  signature.json
  manifest.json       # included when produced by the flow
Photo Evidence Report.pdf
```

The PDF is a human-readable reading copy and is not itself the signed original. Verification must be performed against the original package files.

## Supported Languages

The app UI, permission descriptions, evidence-report strings, and App Store metadata support:

- English
- Korean
- Simplified Chinese
- Traditional Chinese
- Japanese

The signed Evidence Core remains locale-neutral. Translated display text never replaces the original signed observations.

## Privacy and Offline Boundary

- Evidence media and package data remain on the device until the user explicitly exports or shares them.
- Capture, hashing, signing, package finalization, verification, and ZIP export are designed to complete without a service connection.
- Location data is recorded only after system authorization; raw device coordinates remain distinguishable from any display conversion.
- Firebase initialization is conditional on a local `GoogleService-Info.plist`. The active release configuration and privacy manifest should be reviewed before distribution.
- The locked-camera extension operates under Apple's restricted ExtensionKit environment and uses its temporary session container.

## Technology

| Item | Value |
| --- | --- |
| Language | Swift 5.9+ |
| Minimum OS | iOS 18.0 |
| UI | SwiftUI + UIKit bridges |
| Camera and media | AVFoundation, Core Image |
| Persistence | SwiftData, FileManager |
| Location | CoreLocation |
| Integrity | CryptoKit, Security framework, Secure Enclave when available |
| Fast capture | App Intents, WidgetKit, LockedCameraCapture, ExtensionKit |
| Project generation | Tuist 4.x |

## Repository Layout

```text
Sources/
  App/                     App entry point and navigation
  Core/
    Evidence/V2/           Canonical claims, signing payloads, finalizers, verifiers
    Export/                Safe ZIP and multilingual PDF export
    Localization/          Locale-safe committed-text policies
    LockedCapture/         Locked-camera import and handoff policies
    Policy/                Offline and regional claims boundaries
    Storage/               Models, migration, and evidence data safety
    Workflow/              Capture, recording, and export state machines
  Features/
    Camera/                Photo/video capture pipelines and controls
    Gallery/               Local browsing and detail verification UI
    Settings/              User preferences, keys, and support UI
  LockedCaptureExtension/  ExtensionKit locked-camera experience
  Widgets/                 Fast-capture controls
Resources/                 Assets, privacy manifest, policies, string catalogs
Tests/                     Evidence, workflow, localization, and release tests
Documentation/             Design boundaries and characterization notes
```

## Build and Test

### Requirements

- Xcode with the iOS 18 SDK or newer
- Tuist 4.x

### Generate

```bash
tuist install
tuist generate --no-open
```

### Build

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Test

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Replace the simulator name with one installed on your machine when necessary. Physical-device evidence is still required for claims that depend on hardware, camera behavior, Secure Enclave, radio state, or the locked-device environment.

## License

Apache License 2.0. See [LICENSE](LICENSE).
