import SwiftUI
import fiGateCore

private enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case sources
    case gatewaySettings
    case openClawSettings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard / 儀表板"
        case .sources:
            return "Sources / 來源"
        case .gatewaySettings:
            return "Gateway Settings / 閘道設定"
        case .openClawSettings:
            return "OpenClaw / External System / 外部系統"
        case .logs:
            return "Logs / 日誌"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.50percent"
        case .sources:
            return "person.2.fill"
        case .gatewaySettings:
            return "slider.horizontal.3"
        case .openClawSettings:
            return "network"
        case .logs:
            return "doc.text.magnifyingglass"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @AppStorage("fiGate.hasSeenPermissionSetup") private var hasSeenPermissionSetup = false
    @State private var selection: AppSection? = .dashboard
    @State private var isShowingPermissionSetup = false

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("fiGate")
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .sources:
                    SourcesView()
                case .gatewaySettings:
                    GatewaySettingsView()
                case .openClawSettings:
                    OpenClawSettingsView()
                case .logs:
                    LogsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            if !configManager.isLoaded {
                await configManager.load()
            }
        }
        .task {
            if !hasSeenPermissionSetup {
                isShowingPermissionSetup = true
            }
        }
        .sheet(isPresented: $isShowingPermissionSetup) {
            PermissionSetupView(isFirstLaunch: true)
        }
    }
}
