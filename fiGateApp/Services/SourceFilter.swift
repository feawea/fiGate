import Foundation

public actor SourceFilter {
    private let configStore: ConfigStore
    private var cachedAllowedSources: [Source] = []

    public init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
    }

    @discardableResult
    public func reloadAllowedSources() async throws -> [Source] {
        let config = try await configStore.load()
        let allowedSources = config.allowedSources.filter(Self.isSupportedSource)
        cachedAllowedSources = allowedSources
        return allowedSources
    }

    public func isAllowed(sender: String) async -> Bool {
        do {
            let allowedSources = try await reloadAllowedSources()
            return allowedSources.contains { $0.matches(sender) }
        } catch {
            print("fiGate SourceFilter failed to load \(ConfigPaths.configFileURL.path): \(error.localizedDescription)")
            return false
        }
    }

    public func filter(_ messages: [MessageEvent]) async -> [MessageEvent] {
        do {
            let allowedSources = try await reloadAllowedSources()
            return messages.filter { message in
                message.isFromMe || allowedSources.contains { $0.matches(message.sender) }
            }
        } catch {
            print("fiGate SourceFilter failed to filter messages: \(error.localizedDescription)")
            return []
        }
    }

    public func currentAllowedSources() -> [Source] {
        cachedAllowedSources
    }

    private static func isSupportedSource(_ source: Source) -> Bool {
        switch source.kind {
        case .phoneNumber, .email, .appleID:
            return true
        }
    }
}
