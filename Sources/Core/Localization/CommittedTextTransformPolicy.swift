import Foundation

/// Stable accessors for the String Catalog. This preserves the existing
/// `ProvikaStrings.Localizable` API after migration away from legacy `.strings` files.
enum ProvikaStrings {
    enum Localizable {
        private static func value(_ key: String) -> String {
            NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
        }

        enum Common {
            static var cancel: String { value("common.cancel") }
            static var delete: String { value("common.delete") }
            static var ok: String { value("common.ok") }
            static var save: String { value("common.save") }
            static var select: String { value("common.select") }
            static var share: String { value("common.share") }
        }

        enum Tab {
            static var camera: String { value("tab.camera") }
            static var gallery: String { value("tab.gallery") }
            static var settings: String { value("tab.settings") }
        }

        enum Camera {
            enum Permission { enum Denied {
                static var message: String { value("camera.permission.denied.message") }
                static var title: String { value("camera.permission.denied.title") }
            } }
            enum PhotoEvidence {
                static var busy: String { value("camera.photoEvidence.busy") }
                static var failure: String { value("camera.photoEvidence.failure") }
                static var idle: String { value("camera.photoEvidence.idle") }
                static var success: String { value("camera.photoEvidence.success") }
                enum Accessibility {
                    static var hint: String { value("camera.photoEvidence.accessibility.hint") }
                    static var label: String { value("camera.photoEvidence.accessibility.label") }
                }
            }
            enum Record {
                static var start: String { value("camera.record.start") }
                static var stop: String { value("camera.record.stop") }
            }
            enum Recording { static var indicator: String { value("camera.recording.indicator") } }
            enum Flash { enum Accessibility {
                static var hint: String { value("camera.flash.accessibility.hint") }
                static var label: String { value("camera.flash.accessibility.label") }
                static var off: String { value("camera.flash.accessibility.off") }
                static var on: String { value("camera.flash.accessibility.on") }
            } }
        }

        enum Gallery {
            static var title: String { value("gallery.title") }
            enum DatePicker { static var label: String { value("gallery.datePicker.label") } }
            enum Empty {
                static var message: String { value("gallery.empty.message") }
                static var title: String { value("gallery.empty.title") }
            }
            enum Recording { enum Accessibility {
                static var hint: String { value("gallery.recording.accessibility.hint") }
                static var label: String { value("gallery.recording.accessibility.label") }
            } }
            enum Selection {
                static var notSelected: String { value("gallery.selection.notSelected") }
                static var selected: String { value("gallery.selection.selected") }
            }
            enum Detail {
                static var hash: String { value("gallery.detail.hash") }
                static var markReported: String { value("gallery.detail.markReported") }
                static var reported: String { value("gallery.detail.reported") }
                enum Delete { static var confirm: String { value("gallery.detail.delete.confirm") } }
                enum Signature {
                    static var invalid: String { value("gallery.detail.signature.invalid") }
                    static var valid: String { value("gallery.detail.signature.valid") }
                }
            }
        }

        enum Settings {
            static var autoDelete: String { value("settings.autoDelete") }
            static var codec: String { value("settings.codec") }
            static var preRecord: String { value("settings.preRecord") }
            static var quality: String { value("settings.quality") }
            static var title: String { value("settings.title") }
            static var version: String { value("settings.version") }
            enum Overlay {
                static var device: String { value("settings.overlay.device") }
                static var location: String { value("settings.overlay.location") }
                static var timestamp: String { value("settings.overlay.timestamp") }
            }
            enum PublicKey {
                static var copy: String { value("settings.publicKey.copy") }
                static var loadFailure: String { value("settings.publicKey.loadFailure") }
                static var show: String { value("settings.publicKey.show") }
            }
            enum Section {
                static var about: String { value("settings.section.about") }
                static var overlay: String { value("settings.section.overlay") }
                static var recording: String { value("settings.section.recording") }
                static var security: String { value("settings.section.security") }
                static var storage: String { value("settings.section.storage") }
            }
            enum SigningKey {
                static var regenerate: String { value("settings.signingKey.regenerate") }
                enum Confirm {
                    static var action: String { value("settings.signingKey.confirm.action") }
                    static var message: String { value("settings.signingKey.confirm.message") }
                    static var title: String { value("settings.signingKey.confirm.title") }
                }
            }
            enum Value {
                static var days30: String { value("settings.value.days30") }
                static var days90: String { value("settings.value.days90") }
                static var off: String { value("settings.value.off") }
                static var seconds5: String { value("settings.value.seconds5") }
                static var seconds15: String { value("settings.value.seconds15") }
                static var seconds30: String { value("settings.value.seconds30") }
            }
        }

        enum Support {
            static var footer: String { value("support.footer") }
            static var title: String { value("support.title") }
            enum Error { static var generic: String { value("support.error.generic") } }
            enum Thanks {
                static var message: String { value("support.thanks.message") }
                static var title: String { value("support.thanks.title") }
            }
            enum Unavailable {
                static var message: String { value("support.unavailable.message") }
                static var title: String { value("support.unavailable.title") }
            }
            enum Purchase { enum Accessibility {
                static var hint: String { value("support.purchase.accessibility.hint") }
                static var pending: String { value("support.purchase.accessibility.pending") }
                static var purchasing: String { value("support.purchase.accessibility.purchasing") }
            } }
        }
    }
}

/// Chinese IME composition is immutable until marked text commits. Stored user
/// content always preserves the original; only a separate search token may fold case/width.
struct CommittedTextTransformPolicy {
    struct Output: Equatable {
        let preserveOriginal: String
        let searchToken: String
        let composing: Bool
        let committed: Bool
    }

    static func transform(_ input: String, markedText: Bool) -> Output {
        guard !markedText else {
            return Output(preserveOriginal: input, searchToken: input, composing: true, committed: false)
        }
        let search = input.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        return Output(preserveOriginal: input, searchToken: search, composing: false, committed: true)
    }
}
