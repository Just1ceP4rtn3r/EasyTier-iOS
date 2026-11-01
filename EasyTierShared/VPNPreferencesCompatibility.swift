import Foundation
import NetworkExtension

// iOS 15's imported async preference operations can crash while resuming their
// Objective-C completion. Keep that completion entirely outside continuations.
private final class VPNPreferenceResult<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    func finish(_ value: Result<Value, Error>) {
        lock.lock(); defer { lock.unlock() }
        if result == nil { result = value }
    }
    func read() -> Result<Value, Error>? {
        lock.lock(); defer { lock.unlock() }
        return result
    }
}

public enum VPNPreferencesCompatibility {
    private static func wait<Value>(_ result: VPNPreferenceResult<Value>) async throws -> Value {
        let deadline = Date().addingTimeInterval(30)
        while true {
            if let value = result.read() { return try value.get() }
            try Task.checkCancellation()
            if Date() >= deadline {
                throw NSError(domain: "cn.easytier.preferences", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "保存或读取 VPN 配置超时，请重试。"])
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
    public static func save(_ manager: NETunnelProviderManager) async throws {
        let result = VPNPreferenceResult<Void>()
        manager.saveToPreferences { error in
            if let error { result.finish(.failure(error)) }
            else { result.finish(.success(())) }
        }
        try await wait(result)
    }
    public static func reload(_ manager: NETunnelProviderManager) async throws {
        let result = VPNPreferenceResult<Void>()
        manager.loadFromPreferences { error in
            if let error { result.finish(.failure(error)) }
            else { result.finish(.success(())) }
        }
        try await wait(result)
    }
    public static func loadAll() async throws -> [NETunnelProviderManager] {
        let result = VPNPreferenceResult<[NETunnelProviderManager]>()
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error { result.finish(.failure(error)) }
            else { result.finish(.success(managers ?? [])) }
        }
        return try await wait(result)
    }
    public static func remove(_ manager: NETunnelProviderManager) async throws {
        let result = VPNPreferenceResult<Void>()
        manager.removeFromPreferences { error in
            if let error { result.finish(.failure(error)) }
            else { result.finish(.success(())) }
        }
        try await wait(result)
    }
}
