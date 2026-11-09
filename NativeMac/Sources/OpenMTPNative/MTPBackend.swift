import Foundation
import Darwin

struct MTPDeviceInfo: Decodable, Sendable {
    var manufacturer: String?
    var model: String?
    var deviceVersion: String?
    var serialNumber: String?

    enum CodingKeys: String, CodingKey {
        case manufacturer = "Manufacturer"
        case model = "Model"
        case deviceVersion = "DeviceVersion"
        case serialNumber = "SerialNumber"
    }
}

struct MTPDeviceSnapshot: Decodable, Sendable {
    var mtpDeviceInfo: MTPDeviceInfo?
    var usbDeviceInfo: USBDeviceInfo?
}

struct USBDeviceInfo: Decodable, Sendable {
    var manufacturer: String?
    var deviceName: String?
    var vendorId: String?
    var productId: String?
    var serialNumber: String?
}

struct MTPStorageRecord: Decodable, Identifiable, Hashable, Sendable {
    struct StorageInfo: Decodable, Hashable, Sendable {
        var storageDescription: String?
        var maxCapacity: UInt64?
        var freeSpaceInBytes: UInt64?

        enum CodingKeys: String, CodingKey {
            case storageDescription = "StorageDescription"
            case maxCapacity = "MaxCapacity"
            case freeSpaceInBytes = "FreeSpaceInBytes"
        }
    }

    var sid: UInt32
    var info: StorageInfo
    var id: UInt32 { sid }

    enum CodingKeys: String, CodingKey {
        case sid = "Sid"
        case info = "Info"
    }
}

struct MTPFileRecord: Decodable, Identifiable, Hashable, Sendable {
    var size: Int64
    var isFolder: Bool
    var dateAdded: String
    var name: String
    var path: String
    var parentPath: String
    var extensionName: String
    var parentId: UInt32
    var objectId: UInt32
    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case size
        case isFolder
        case dateAdded
        case name
        case path
        case parentPath
        case extensionName = "extension"
        case parentId
        case objectId
    }
}

struct MTPTransferProgress: Decodable, Sendable {
    struct Size: Decodable, Sendable {
        var total: Int64
        var sent: Int64
        var progress: Double
    }

    struct Data: Decodable, Sendable {
        var fullPath: String
        var name: String
        var speed: Double
        var filesSent: Int64
        var totalFiles: Int64
        var activeFileSize: Size
        var bulkFileSize: Size
        var status: String
    }

    var data: Data?
    var error: String?
    var errorType: String?
}

enum MTPBackendError: LocalizedError {
    case libraryUnavailable(String)
    case missingSymbol(String)
    case operation(String, String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable(let message), .missingSymbol(let message), .operation(_, let message):
            message
        case .malformedResponse:
            "The MTP engine returned a response the app could not read."
        }
    }
}

private final class MTPCallbackRouter: @unchecked Sendable {
    static let shared = MTPCallbackRouter()
    private let lock = NSLock()
    private var result: ((String) -> Void)?
    private var preprocess: ((String) -> Void)?
    private var progress: ((String) -> Void)?

    func install(
        result: @escaping (String) -> Void,
        preprocess: @escaping (String) -> Void = { _ in },
        progress: @escaping (String) -> Void = { _ in }
    ) {
        lock.lock()
        self.result = result
        self.preprocess = preprocess
        self.progress = progress
        lock.unlock()
    }

    func deliver(_ kind: Kind, payload: String) {
        lock.lock()
        let handler: ((String) -> Void)?
        switch kind {
        case .result: handler = result
        case .preprocess: handler = preprocess
        case .progress: handler = progress
        }
        lock.unlock()
        handler?(payload)
    }

    enum Kind { case result, preprocess, progress }
}

private func routeMTPCallback(_ payload: UnsafeMutablePointer<CChar>?, kind: MTPCallbackRouter.Kind) {
    guard let payload else { return }
    let value = String(cString: payload)
    free(payload) // The Go bridge allocates callback payloads with C.CString.
    MTPCallbackRouter.shared.deliver(kind, payload: value)
}

@_cdecl("openmtp_kalam_result")
private func openMTPKalamResult(_ payload: UnsafeMutablePointer<CChar>?) {
    routeMTPCallback(payload, kind: .result)
}

@_cdecl("openmtp_kalam_preprocess")
private func openMTPKalamPreprocess(_ payload: UnsafeMutablePointer<CChar>?) {
    routeMTPCallback(payload, kind: .preprocess)
}

@_cdecl("openmtp_kalam_progress")
private func openMTPKalamProgress(_ payload: UnsafeMutablePointer<CChar>?) {
    routeMTPCallback(payload, kind: .progress)
}

private typealias SimpleKalamFunction = @convention(c) (UnsafeMutableRawPointer?) -> Void
private typealias InputKalamFunction = @convention(c) (UnsafePointer<CChar>, UnsafeMutableRawPointer?) -> Void
private typealias TransferKalamFunction = @convention(c) (
    UnsafePointer<CChar>, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
) -> Void
private typealias MTPCallback = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void

actor KalamBackend {
    private var libraryHandle: UnsafeMutableRawPointer?
    private var invocationInProgress = false
    private var invocationWaiters: [CheckedContinuation<Void, Never>] = []

    func initialize() async throws -> MTPDeviceSnapshot {
        try decodeData(MTPDeviceSnapshot.self, from: await invoke("Initialize"))
    }

    func storages() async throws -> [MTPStorageRecord] {
        try decodeData([MTPStorageRecord].self, from: await invoke("FetchStorages"))
    }

    func files(storageID: UInt32, path: String, showHidden: Bool) async throws -> [MTPFileRecord] {
        let input = try json([
            "storageId": storageID,
            "fullPath": path,
            "recursive": false,
            "skipDisallowedFiles": false,
            "skipHiddenFiles": !showHidden
        ])
        return try decodeData([MTPFileRecord].self, from: await invoke("Walk", input: input))
    }

    func createFolder(storageID: UInt32, path: String) async throws {
        let input = try json(["storageId": storageID, "fullPath": path])
        try checkResult(await invoke("MakeDirectory", input: input))
    }

    func rename(storageID: UInt32, path: String, newName: String) async throws {
        let input = try json(["storageId": storageID, "fullPath": path, "newFileName": newName])
        try checkResult(await invoke("RenameFile", input: input))
    }

    func delete(storageID: UInt32, paths: [String]) async throws {
        let input = try json(["storageId": storageID, "Files": paths])
        try checkResult(await invoke("DeleteFile", input: input))
    }

    func transfer(
        direction: TransferDirection,
        storageID: UInt32,
        sources: [String],
        destination: String,
        onPreprocess: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (MTPTransferProgress) -> Void
    ) async throws {
        let input = try json([
            "storageId": storageID,
            "sources": sources,
            "destination": destination,
            "preprocessFiles": true
        ])
        let symbol = direction == .download ? "DownloadFiles" : "UploadFiles"
        _ = try await invoke(symbol, input: input, onPreprocess: onPreprocess) { raw in
            guard let data = raw.data(using: .utf8),
                  let event = try? JSONDecoder().decode(MTPTransferProgress.self, from: data) else { return }
            if let error = event.error, !error.isEmpty {
                onProgress(event)
                return
            }
            onProgress(event)
        }
    }

    func dispose() async throws {
        try checkResult(await invoke("Dispose"))
    }

    private func invoke(
        _ symbol: String,
        input: String? = nil,
        onPreprocess: @escaping (String) -> Void = { _ in },
        onProgress: @escaping (String) -> Void = { _ in }
    ) async throws -> String {
        // The Kalam C bridge has one process-wide callback slot. Keep only one call in
        // flight so a device poll or second UI action cannot replace its handlers.
        await acquireInvocation()
        do {
            let functionAddress = try address(of: symbol)
            let result = try await withCheckedThrowingContinuation { continuation in
            MTPCallbackRouter.shared.install(result: { payload in
                do {
                    try Self.throwIfBackendError(payload)
                    continuation.resume(returning: payload)
                } catch {
                    continuation.resume(throwing: error)
                }
            }, preprocess: onPreprocess, progress: onProgress)

            let resultCallback = unsafeBitCast(openMTPKalamResult as MTPCallback, to: UnsafeMutableRawPointer.self)
            if let input {
                input.withCString { cInput in
                    if symbol == "UploadFiles" || symbol == "DownloadFiles" {
                        let transfer = unsafeBitCast(functionAddress, to: TransferKalamFunction.self)
                        let preprocessCallback = unsafeBitCast(openMTPKalamPreprocess as MTPCallback, to: UnsafeMutableRawPointer.self)
                        let progressCallback = unsafeBitCast(openMTPKalamProgress as MTPCallback, to: UnsafeMutableRawPointer.self)
                        transfer(cInput, preprocessCallback, progressCallback, resultCallback)
                    } else {
                        let function = unsafeBitCast(functionAddress, to: InputKalamFunction.self)
                        function(cInput, resultCallback)
                    }
                }
            } else {
                let function = unsafeBitCast(functionAddress, to: SimpleKalamFunction.self)
                function(resultCallback)
            }
            }
            releaseInvocation()
            return result
        } catch {
            releaseInvocation()
            throw error
        }
    }

    private func acquireInvocation() async {
        if !invocationInProgress {
            invocationInProgress = true
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            invocationWaiters.append(continuation)
        }
    }

    private func releaseInvocation() {
        if invocationWaiters.isEmpty {
            invocationInProgress = false
        } else {
            invocationWaiters.removeFirst().resume()
        }
    }

    private func address(of symbol: String) throws -> UnsafeMutableRawPointer {
        if libraryHandle == nil {
            guard let libraryURL = Self.libraryURL() else {
                throw MTPBackendError.libraryUnavailable("The bundled Kalam MTP engine was not found.")
            }
            libraryHandle = dlopen(libraryURL.path, RTLD_NOW | RTLD_LOCAL)
            guard libraryHandle != nil else {
                let detail = dlerror().map { String(cString: $0) } ?? "Unknown dynamic library error"
                throw MTPBackendError.libraryUnavailable("Could not load the MTP engine: \(detail)")
            }
        }
        guard let libraryHandle, let function = dlsym(libraryHandle, symbol) else {
            throw MTPBackendError.missingSymbol("The MTP engine does not provide \(symbol).")
        }
        return function
    }

    private static func libraryURL() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("bin/kalam-seg5.dylib"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("build/mac/bin/arm64/kalam-seg5.dylib")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func json(_ value: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func decodeData<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        let data = Data(raw.utf8)
        let envelope = try JSONDecoder().decode(MTPEnvelope<T>.self, from: data)
        if let error = envelope.error, !error.isEmpty {
            throw MTPBackendError.operation(envelope.errorType ?? "", error)
        }
        guard let value = envelope.data else { throw MTPBackendError.malformedResponse }
        return value
    }

    private func checkResult(_ raw: String) throws {
        try Self.throwIfBackendError(raw)
    }

    private static func throwIfBackendError(_ raw: String) throws {
        guard let data = raw.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MTPBackendError.malformedResponse
        }
        if let error = envelope["error"] as? String, !error.isEmpty {
            throw MTPBackendError.operation(envelope["errorType"] as? String ?? "", error)
        }
    }
}

enum TransferDirection: Sendable, Equatable { case upload, download }

private struct MTPEnvelope<Value: Decodable>: Decodable {
    var errorType: String?
    var error: String?
    var data: Value?
}

