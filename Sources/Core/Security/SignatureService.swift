import Foundation
import Security
import CryptoKit
import os

final class SignatureService {
    private let keyTag = "com.bbdyno.app.provika.signing.key"
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "Signature")

    func getOrCreateKey() throws -> SecKey {
        if let existingKey = try? getKey() {
            return existingKey
        }
        return try createKey()
    }

    func sign(data: Data) throws -> Data {
        let privateKey = try getOrCreateKey()
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) else {
            throw SignatureError.signingFailed(error?.takeRetainedValue())
        }
        return signature as Data
    }

    func publicKeyData() throws -> Data {
        let privateKey = try getOrCreateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SignatureError.publicKeyExportFailed
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw SignatureError.publicKeyExportFailed
        }
        return publicKeyData as Data
    }

    func publicKeyPEM() throws -> String {
        let data = try publicKeyData()
        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"
    }

    func verify(signature: Data, data: Data) throws -> Bool {
        let privateKey = try getOrCreateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SignatureError.publicKeyExportFailed
        }
        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &error
        )
        return result
    }

    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SignatureError.keyDeletionFailed(status)
        }
        logger.info("서명 키 삭제 완료")
    }

    // MARK: - Private

    private func getKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw SignatureError.keyNotFound
        }
        return item as! SecKey
    }

    private func createKey() throws -> SecKey {
        var accessControlError: Unmanaged<CFError>?

        // Secure Enclave 사용 시도, 시뮬레이터에서는 일반 Keychain 사용
        let accessControl: SecAccessControl?
        if hasSecureEnclave() {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .privateKeyUsage,
                &accessControlError
            )
        } else {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [],
                &accessControlError
            )
        }

        guard let access = accessControl else {
            throw SignatureError.keyCreationFailed(accessControlError?.takeRetainedValue())
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access
            ] as [String: Any]
        ]

        if hasSecureEnclave() {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SignatureError.keyCreationFailed(error?.takeRetainedValue())
        }

        logger.info("서명 키 생성 완료 (Secure Enclave: \(self.hasSecureEnclave()))")
        return privateKey
    }

    private func hasSecureEnclave() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    enum SignatureError: Error {
        case keyNotFound
        case keyCreationFailed(CFError?)
        case signingFailed(CFError?)
        case publicKeyExportFailed
        case keyDeletionFailed(OSStatus)
    }
}
