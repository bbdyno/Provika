# Legacy Video Characterization

This task freezes current behavior; it makes no format or migration change. Legacy media is stored under Documents/Recordings in date folders as paired `.mov` and `RecordingMetadata` v1 `.json` files. SwiftData `Recording` keeps the two paths. `FileStorage.deleteRecording` attempts deletion of both.

The finalized `.mov` bytes receive a SHA-256 lowercase-hex hash. `SignatureService` signs the UTF-8 hash text and stores the signature and public key in metadata. The Keychain-free `EvidencePackageVerifier` validates the embedded key, signature, and hash offline and exposes typed mutation outcomes.

There is an intentional verifier/UI gap: `EvidencePackageVerifier` can independently use the embedded public key, while the legacy `VideoDetailView` asks the device-bound `SignatureService` to verify. Its `ShareLink` shares the video URL only, not the JSON sidecar. This is characterized, not silently repaired here.

The versioned behavior matrix records automated observations, source observations, and each external `proof-gap`. Microphone denial, app/tab disappearance, backgrounding, AV interruption, writer failure, temporary/incomplete files, deletion, and legacy-user compatibility must not be reported as device-proven without exact-build evidence. Future migration work must preserve these inputs or explicitly version its conversion and rollback behavior.
