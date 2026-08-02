# China Offline Core Flow

This boundary is global and does not create a China-only Evidence Core. The exact build must complete capture, immutable original storage, SHA-256 hash, canonical claim, signature, independent Keychain-free verification, and safe ZIP export without a service connection.

Reverse geocoding, analytics, and other presentation services are optional. Failure or absence of those services cannot block Core output. Raw `core-location-device` observations remain in the signed claim. Any displayed coordinate conversion records its source coordinate system, target coordinate system, and algorithm; it never replaces the raw observation.

The MVP sharing edge is the iOS system share sheet (`ShareLink`/`UIActivityViewController`). No WeChat, DingTalk, or other region-specific SDK is required.

## Agent-operable verification

1. Build and install the exact fingerprint on an online physical iPhone.
2. Independently observe and record Airplane Mode and radio state before capture.
3. Capture media, finalize the package, verify it independently, and export ZIP.
4. Hash the media, claim, signature envelope, ZIP, logs, and build fingerprint into the evidence record.
5. Confirm optional analytics and reverse-geocoding failures did not stop the flow.

Simulator output and synthetic media can validate deterministic policy logic but cannot prove radio state. Until exact-build physical evidence is collected, `AIRPLANE_MODE_CORE_FLOW_DEVICE` remains `ABSTAIN/AWAITING_EVIDENCE`; automatic G4-T04 completion covers only implementation and focused tests.
