import SwiftUI

import EasyTierShared

struct NetworkSettingsSheet: View {
    @Binding var settings: TunnelNetworkSettingsSnapshot?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        CompatNavigationStack {
            Form {
                if let settings {
                    if let ipv4 = settings.ipv4 {
                        Section(header: Text("ipv4")) {
                            labeledLines("address", values: formatIPv4Addresses(Array(ipv4.subnets)))
                        }
                        if let routes = ipv4.includedRoutes, !routes.isEmpty {
                            Section(header: Text("ipv4_routes_included")) {
                                ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                                    Text(formatIPv4Route(route))
                                }
                            }
                        }
                        if let routes = ipv4.excludedRoutes, !routes.isEmpty {
                            Section(header: Text("ipv4_routes_excluded")) {
                                ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                                    Text(formatIPv4Route(route))
                                }
                            }
                        }
                    }

                    if let ipv6 = settings.ipv6 {
                        Section(header: Text("ipv6")) {
                            labeledLines("address", values: formatIPv6Addresses(Array(ipv6.subnets)))
                        }
                        if let routes = ipv6.includedRoutes, !routes.isEmpty {
                            Section(header: Text("ipv6_routes_included")) {
                                ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                                    Text("\(route.address)/\(route.networkPrefixLength)")
                                }
                            }
                        }
                        if let routes = ipv6.excludedRoutes, !routes.isEmpty {
                            Section(header: Text("ipv6_routes_excluded")) {
                                ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                                    Text("\(route.address)/\(route.networkPrefixLength)")
                                }
                            }
                        }
                    }

                    if let dns = settings.dns {
                        Section(header: Text("dns")) {
                            labeledLines("server", values: Array(dns.servers))
                            if let search = dns.searchDomains, !search.isEmpty {
                                labeledLines("search_domains", values: Array(search))
                            }
                            if let match = dns.matchDomains, !match.isEmpty {
                                labeledLines("match_domains", values: formatMatchDomains(Array(match)))
                            }
                        }
                    }

                    if let mtu = settings.mtu {
                        Section(header: Text("mtu")) {
                            CompatLabeledContent("mtu", value: String(mtu))
                        }
                    }
                } else {
                    Section {
                        Text("no_settings_available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .compatTextSelection()
            .navigationTitle("network_settings")
            .adaptiveNavigationBarTitleInline()

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func labeledLines(_ label: LocalizedStringKey, values: [String]) -> some View {
        CompatLabeledContent(label) {
            Text(values.isEmpty ? NSLocalizedString("not_available", comment: "") : values.joined(separator: "\n"))
        }
    }

    private func formatIPv4Addresses(_ subnets: [TunnelNetworkSettingsSnapshot.IPv4Subnet]) -> [String] {
        var results: [String] = []
        results.reserveCapacity(subnets.count)
        for subnet in subnets {
            if let prefix = ipv4PrefixLength(from: subnet.subnetMask) {
                results.append("\(subnet.address)/\(prefix)")
            } else {
                results.append(subnet.address)
            }
        }
        return results
    }

    private func formatIPv6Addresses(_ subnets: [TunnelNetworkSettingsSnapshot.IPv6Subnet]) -> [String] {
        return subnets.map { "\($0.address)/\($0.networkPrefixLength)" }
    }

    private func formatMatchDomains(_ domains: [String]) -> [String] {
        domains.map { domain in
            domain.isEmpty ? NSLocalizedString("all_domains", comment: "") : domain
        }
    }

    private func formatIPv4Route(_ route: TunnelNetworkSettingsSnapshot.IPv4Subnet) -> String {
        if let prefix = ipv4PrefixLength(from: route.subnetMask) {
            return "\(route.address)/\(prefix)"
        }
        return "\(route.address)/\(route.subnetMask)"
    }

    private func ipv4PrefixLength(from mask: String) -> Int? {
        let parts = mask.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            value = (value << 8) | octet
        }
        var prefix = 0
        var seenZero = false
        for bit in (0..<32).reversed() {
            let isSet = (value & (1 << bit)) != 0
            if isSet {
                if seenZero { return nil }
                prefix += 1
            } else {
                seenZero = true
            }
        }
        return prefix
    }
}

struct PeerConnDetailSheet: View {
    @Binding var status: NetworkStatus?
    @Environment(\.presentationMode) private var presentationMode
    let peerRouteID: Int

    var pair: NetworkStatus.PeerRoutePair? {
        status?.peerRoutePairs.first { $0.id == peerRouteID }
    }

    var conns: [NetworkStatus.PeerConnInfo] {
        pair?.peer?.conns ?? []
    }

    var body: some View {
        CompatNavigationStack {
            Form {
                if let pair {
                    Section(header: Text("peer")) {
                        CompatLabeledContent("hostname", value: pair.route.hostname)
                        CompatLabeledContent("peer_id", value: String(pair.route.peerId))
                        if let ipv4 = pair.route.ipv4Addr {
                            CompatLabeledContent("ipv4_addr", value: ipv4.description)
                        }
                        if let ipv6 = pair.route.ipv6Addr {
                            CompatLabeledContent("ipv6_addr", value: ipv6.description)
                        }
                        CompatLabeledContent("inst_id", value: String(pair.route.instId))
                        CompatLabeledContent("version", value: String(pair.route.version))
                        CompatLabeledContent("next_hop_peer_id", value: String(pair.route.nextHopPeerId))
                        CompatLabeledContent("cost", value: String(pair.route.cost))
                        CompatLabeledContent("path_latency", value: latencyValueString(pair.route.pathLatency))
                        if let nextHopLatencyFirst = pair.route.nextHopPeerIdLatencyFirst {
                            CompatLabeledContent("next_hop_peer_id_latency_first", value: String(nextHopLatencyFirst))
                        }
                        if let costLatencyFirst = pair.route.costLatencyFirst {
                            CompatLabeledContent("cost_latency_first", value: String(costLatencyFirst))
                        }
                        if let pathLatencyLatencyFirst = pair.route.pathLatencyLatencyFirst {
                            CompatLabeledContent("path_latency_latency_first", value: latencyValueString(pathLatencyLatencyFirst))
                        }
                        if let featureFlags = pair.route.featureFlag {
                            CompatLabeledContent("feature_flag", value: featureFlagString(featureFlags))
                        }
                        if let peerInfo = pair.peer {
                            if let defaultConnId = peerInfo.defaultConnId {
                                CompatLabeledContent("default_conn_id", value: uuidString(defaultConnId))
                            }
                            if !peerInfo.directlyConnectedConns.isEmpty {
                                CompatLabeledContent(
                                    "directly_connected_conns",
                                    value: peerInfo.directlyConnectedConns.map(uuidString).sorted().joined(separator: "\n")
                                )
                            }
                        }
                    }

                    if !pair.route.proxyCIDRs.isEmpty {
                        Section(header: Text("proxy_cidrs")) {
                            ForEach(pair.route.proxyCIDRs, id: \.hashValue) {
                                Text($0)
                            }
                        }
                    }

                    if conns.isEmpty {
                        Section(header: Text("connections")) {
                            Text("no_connection_details_available")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(conns, id: \.connId) { conn in
                            Section(header: Text("connection_\(conn.connId)")) {
                                CompatLabeledContent("peer_id", value: String(conn.peerId))
                                CompatLabeledContent("role", value: conn.isClient ? "Client" : "Server")
                                CompatLabeledContent("loss_rate", value: percentString(conn.lossRate))
                                CompatLabeledContent("closed", value: triState(conn.isClosed))

                                CompatLabeledContent("features", value: conn.features.isEmpty ? "None" : conn.features.joined(separator: ", "))

                                if let tunnel = conn.tunnel {
                                    CompatLabeledContent("tunnel_type", value: tunnel.tunnelType.uppercased())
                                    if let localAddr = tunnel.localAddr {
                                        CompatLabeledContent("local_addr", value: localAddr.url)
                                    }
                                    if let remoteAddr = tunnel.remoteAddr {
                                        CompatLabeledContent("remote_addr", value: remoteAddr.url)
                                    }
                                }

                                if let stats = conn.stats {
                                    CompatLabeledContent("rx_bytes", value: formatBytes(stats.rxBytes))
                                    CompatLabeledContent("tx_bytes", value: formatBytes(stats.txBytes))
                                    CompatLabeledContent("rx_packets", value: String(stats.rxPackets))
                                    CompatLabeledContent("tx_packets", value: String(stats.txPackets))
                                    CompatLabeledContent("latency", value: latencyString(stats.latencyUs))
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("no_peer_information_available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .compatTextSelection()
            .navigationTitle("peer_details")
            .adaptiveNavigationBarTitleInline()

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func formatBytes(_ value: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(value))
    }

    private func latencyString(_ us: Int) -> String {
        String(format: "%.1f ms", Double(us) / 1000.0)
    }

    private func latencyValueString(_ value: Int) -> String {
        "\(value) ms"
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    private func triState(_ value: Bool?) -> String {
        guard let value else { return "event.Unknown" }
        return value ? "Yes" : "No"
    }

    private func uuidString(_ value: NetworkStatus.UUID) -> String {
        String(format: "%08x-%08x-%08x-%08x", value.part1, value.part2, value.part3, value.part4)
    }

    private func featureFlagString(_ flags: NetworkStatus.PeerFeatureFlag) -> String {
        var enabled: [String] = []
        if flags.isPublicServer { enabled.append("is_public_server") }
        if flags.avoidRelayData { enabled.append("avoid_relay_data") }
        if flags.kcpInput { enabled.append("kcp_input") }
        if flags.noRelayKcp { enabled.append("no_relay_kcp") }
        if flags.supportConnListSync { enabled.append("support_conn_list_sync") }
        return enabled.isEmpty ? "None" : enabled.joined(separator: ", ")
    }
}

struct NodeInfoSheet: View {
    @Binding var status: NetworkStatus?
    @Environment(\.presentationMode) private var presentationMode

    var nodeInfo: NetworkStatus.MyNodeInfo? {
        status?.myNodeInfo
    }
    
    var body: some View {
        CompatNavigationStack {
            Form {
                if let nodeInfo {
                    Section(header: Text("general")) {
                        CompatLabeledContent("hostname", value: nodeInfo.hostname)
                        if let peerID = nodeInfo.peerID {
                            CompatLabeledContent("peer_id", value: String(peerID))
                        }
                        CompatLabeledContent("version", value: nodeInfo.version)
                        if let virtualIPv4 = nodeInfo.virtualIPv4 {
                            CompatLabeledContent("virtual_ipv4", value: virtualIPv4.description)
                        }
                    }
                } else {
                    Section {
                        Text("no_node_information_available")
                    }
                }
            }
            .compatTextSelection()
            .navigationTitle("node_information")
            .adaptiveNavigationBarTitleInline()

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct IPInfoSheet: View {
    @Binding var status: NetworkStatus?
    @Environment(\.presentationMode) private var presentationMode

    var nodeInfo: NetworkStatus.MyNodeInfo? {
        status?.myNodeInfo
    }
    
    var body: some View {
        CompatNavigationStack {
            Form {
                if let nodeInfo {
                    if let virtualIPv4 = nodeInfo.virtualIPv4 {
                        Section(header: Text("general")) {
                            CompatLabeledContent("virtual_ipv4", value: virtualIPv4.description)
                        }
                    }
                    
                    if let ips = nodeInfo.ips {
                        if ips.publicIPv4 != nil || ips.publicIPv6 != nil {
                            Section(header: Text("ip_information")) {
                                if let publicIPv4 = ips.publicIPv4 {
                                    CompatLabeledContent("public_ipv4", value: publicIPv4.description)
                                }
                                if let publicIPv6 = ips.publicIPv6 {
                                    CompatLabeledContent("public_ipv6", value: publicIPv6.description)
                                }
                            }
                        }
                        if let v4s = ips.interfaceIPv4s, !v4s.isEmpty {
                            Section(header: Text("interface_ipv4s")) {
                                ForEach(Array(Set(v4s)).map(\.description).sorted(), id: \.hashValue) { ip in
                                    Text(ip)
                                }
                            }
                        }
                        if let v6s = ips.interfaceIPv6s, !v6s.isEmpty {
                            Section(header: Text("interface_ipv6s")) {
                                ForEach(Array(Set(v6s)).map(\.description).sorted(), id: \.hashValue) { ip in
                                    Text(ip)
                                }
                            }
                        }
                    }
                    
                    if let listeners = nodeInfo.listeners, !listeners.isEmpty {
                        Section(header: Text("listeners")) {
                            ForEach(listeners, id: \.url) { listener in
                                Text(listener.url)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("no_ip_information_available")
                    }
                }
            }
            .compatTextSelection()
            .navigationTitle("ip_information")
            .adaptiveNavigationBarTitleInline()

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct StunInfoSheet: View {
    @Binding var status: NetworkStatus?
    @Environment(\.presentationMode) private var presentationMode

    var stunInfo: NetworkStatus.STUNInfo? {
        status?.myNodeInfo?.stunInfo
    }
    
    var body: some View {
        CompatNavigationStack {
            Form {
                if let stunInfo {
                    Section(header: Text("nat_types")) {
                        CompatLabeledContent("udp_nat_type") {
                            Text(stunInfo.udpNATType.description)
                        }
                        CompatLabeledContent("tcp_nat_type") {
                            Text(stunInfo.tcpNATType.description)
                        }
                    }
                    
                    Section(header: Text("details")) {
                        CompatLabeledContent("last_update", value: formatDate(stunInfo.lastUpdateTime))
                        if let minPort = stunInfo.minPort {
                            CompatLabeledContent("min_port", value: String(minPort))
                        }
                        if let maxPort = stunInfo.maxPort {
                            CompatLabeledContent("max_port", value: String(maxPort))
                        }
                    }
                    
                    if !stunInfo.publicIPs.isEmpty {
                        Section(header: Text("public_ips")) {
                            ForEach(stunInfo.publicIPs, id: \.self) { ip in
                                Text(ip)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("no_stun_information_available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("stun_information")
            .adaptiveNavigationBarTitleInline()
            .compatTextSelection()

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
