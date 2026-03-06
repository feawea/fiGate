import Combine
import Foundation

public enum ConfigPaths {
    public static var appSupportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["FIGATE_APP_SUPPORT_DIRECTORY"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(
                fileURLWithPath: NSString(string: override).expandingTildeInPath,
                isDirectory: true
            )
        }

        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("fiGate", isDirectory: true)
    }

    public static var logsDirectory: URL {
        appSupportDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    public static var configFileURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    public static func expandedPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}

public actor ConfigStore {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func load() throws -> Config {
        try ensureSupportDirectories()

        let configURL = ConfigPaths.configFileURL
        guard fileManager.fileExists(atPath: configURL.path) else {
            let defaultConfig = Config.defaultValue
            try save(defaultConfig)
            return defaultConfig
        }

        let data = try Data(contentsOf: configURL)
        return try decoder.decode(Config.self, from: data)
    }

    public func save(_ config: Config) throws {
        try ensureSupportDirectories()
        let data = try encoder.encode(config)
        try data.write(to: ConfigPaths.configFileURL, options: .atomic)
    }

    private func ensureSupportDirectories() throws {
        try fileManager.createDirectory(at: ConfigPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: ConfigPaths.logsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
}

@MainActor
public final class ConfigManager: ObservableObject {
    @Published public var config: Config = .defaultValue
    @Published public private(set) var isLoaded = false
    @Published public private(set) var lastSaveError: String?

    private let store: ConfigStore

    public init(store: ConfigStore = ConfigStore()) {
        self.store = store

        Task {
            await load()
        }
    }

    public func load() async {
        do {
            config = try await store.load()
            isLoaded = true
            lastSaveError = nil
        } catch {
            isLoaded = false
            lastSaveError = error.localizedDescription
        }
    }

    @discardableResult
    public func save() async -> Bool {
        do {
            try await store.save(config)
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = error.localizedDescription
            return false
        }
    }

    public func addSource(_ value: String) {
        let newSource = Source(value: value)
        guard !config.allowedSources.contains(newSource) else {
            return
        }

        config.allowedSources.append(newSource)
        config.allowedSources.sort { lhs, rhs in
            lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
        }
    }

    public func removeSource(_ source: Source) {
        config.allowedSources.removeAll { $0 == source }
    }

    public var gatewayStatusText: String {
        if config.openClawToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Needs external system token"
        }

        if URL(string: config.openClawEndpoint) == nil {
            return "Invalid external system endpoint"
        }

        if config.allowedSources.isEmpty {
            return "No allowed sources configured"
        }

        return "Ready"
    }
}
