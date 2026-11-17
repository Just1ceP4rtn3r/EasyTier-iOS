import NetworkExtension
import AppIntents
import SwiftUI
import WidgetKit

import EasyTierShared

struct VPNStatusEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let profileName: String
    let ipAddress: String?
    
    init(date: Date, isConnected: Bool, profileName: String, ipAddress: String? = nil) {
        self.date = date
        self.isConnected = isConnected
        self.profileName = profileName
        self.ipAddress = ipAddress
    }
}

struct VPNStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> VPNStatusEntry {
        VPNStatusEntry(date: Date(), isConnected: false, profileName: "")
    }

    func getSnapshot(in context: Context, completion: @Sendable @escaping (VPNStatusEntry) -> Void) {
        Task {
            let isConnected = await fetchConnectionStatus()
            let profileName = fetchProfileName()
            completion(VPNStatusEntry(date: Date(), isConnected: isConnected, profileName: profileName, ipAddress: getIPv4Address()))
        }
    }

    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<VPNStatusEntry>) -> Void) {
        Task {
            let isConnected = await fetchConnectionStatus()
            let profileName = fetchProfileName()
            let entry = VPNStatusEntry(date: Date(), isConnected: isConnected, profileName: profileName, ipAddress: getIPv4Address())
            let nextRefresh = Date().addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
    
    func getOptions() -> EasyTierOptions? {
        let defaults = UserDefaults(suiteName: APP_GROUP_ID)
        guard let configData = defaults?.data(forKey: "VPNConfig"),
              let options = try? JSONDecoder().decode(EasyTierOptions.self, from: configData) else {
            return nil
        }
        return options
    }
    
    func getIPv4Address() -> String? {
        return getOptions()?.ipv4?.description
    }

    private func fetchConnectionStatus() async -> Bool {
        do {
            let managers = try await NETunnelProviderManager.compatLoadAllFromPreferences()
            guard let manager = managers.first else {
                return false
            }
            return [.connecting, .connected, .reasserting].contains(manager.connection.status)
        } catch {
            return false
        }
    }

    private func fetchProfileName() -> String {
        if getOptions()?.mode == .web { return NSLocalizedString("web_management.title", comment: "") }
        let defaults = UserDefaults(suiteName: APP_GROUP_ID)
        return defaults?.string(forKey: "selectedProfileName") ?? ""
    }
}

struct VPNStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: VPNStatusProvider.Entry
    
    var badgeColor: Color {
        if entry.isConnected {
            .green
        } else {
            .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 8, height: 8)
                    Text(entry.isConnected ? "vpn_connected" : "vpn_disconnected")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(badgeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeColor.opacity(0.1))
                .clipShape(Capsule())
                .layoutPriority(1)
                if family != .systemSmall {
                    Spacer(minLength: 8)
                    Text("EasyTier")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text(entry.profileName.isEmpty ? "select_network" : LocalizedStringKey(entry.profileName))
                .font(family == .systemSmall ? .title2.bold() : .title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if entry.isConnected {
                Text(entry.ipAddress ?? "DHCP")
                    .font(family == .systemSmall ? .subheadline : .callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                Group {
                    let text: LocalizedStringKey = entry.isConnected ? "vpn_disconnect" : "vpn_connect"
                    if #available(iOS 17.0, macOS 14.0, *) {
                        Button(text, intent: ToggleVPNConnectionIntent())
                    } else {
                        Link(destination: URL(string: "easytier://")!) { Text(text).padding(8).background(Color.accentColor).foregroundColor(.white).cornerRadius(8) }
                    }
                }
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackgroundStyle()
    }
}

struct EasyTierStatusWidget: Widget {
    static let kind: String = "\(APP_BUNDLE_ID).widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: VPNStatusProvider()) { entry in
            VPNStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("EasyTier")
        .description("widget_desc")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOS 16, macOS 13, *)
struct ToggleVPNConnectionIntent: AppIntent {
    static let title: LocalizedStringResource = "toggle_vpn"

    func perform() async throws -> some IntentResult {
        let managers = try await NETunnelProviderManager.compatLoadAllFromPreferences()
        guard let manager = managers.first else {
            throw TunnelManagerError.unavailable
        }

        let isConnected = [.connecting, .connected, .reasserting].contains(manager.connection.status)
        if isConnected {
            manager.connection.stopVPNTunnel()
        } else {
            try await connectWithManager(manager)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "\(APP_BUNDLE_ID).widget")
        return .result()
    }
}

extension View {
    @ViewBuilder
    func widgetBackgroundStyle() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview(
    "Connected",
    as: .systemSmall,
    widget: {
        EasyTierStatusWidget()
    },
    timeline: {
        VPNStatusEntry(date: Date(), isConnected: true, profileName: "Example")
    }
)

@available(iOS 17.0, macOS 14.0, *)
#Preview(
    "Connected Medium",
    as: .systemMedium,
    widget: {
        EasyTierStatusWidget()
    },
    timeline: {
        VPNStatusEntry(date: Date(), isConnected: true, profileName: "Example")
    }
)

@available(iOS 17.0, macOS 14.0, *)
#Preview(
    "Disconnected",
    as: .systemSmall,
    widget: {
        EasyTierStatusWidget()
    },
    timeline: {
        VPNStatusEntry(date: Date(), isConnected: false, profileName: "Test")
    }
)
#endif
