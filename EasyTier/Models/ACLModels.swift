import Foundation

enum ACLChainType: Int, Codable, CaseIterable, Identifiable {
    case unspecified = 0
    case inbound = 1
    case outbound = 2
    case forward = 3

    var id: Int { rawValue }

    static let configurableCases: [ACLChainType] = [.inbound, .outbound, .forward]
}

enum ACLAction: Int, Codable, CaseIterable, Identifiable {
    case noop = 0
    case allow = 1
    case drop = 2

    var id: Int { rawValue }

    static let configurableCases: [ACLAction] = [.allow, .drop]
}

enum ACLProtocol: Int, Codable, CaseIterable, Identifiable {
    case unspecified = 0
    case tcp = 1
    case udp = 2
    case icmp = 3
    case icmpV6 = 4
    case any = 5

    var id: Int { rawValue }

    static let configurableCases: [ACLProtocol] = [.any, .tcp, .udp, .icmp, .icmpV6]
}

struct ACLConfig: Codable, Equatable {
    var aclV1: ACLV1

    enum CodingKeys: String, CodingKey {
        case aclV1 = "acl_v1"
    }

    init(aclV1: ACLV1 = .init()) {
        self.aclV1 = aclV1
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aclV1 = try container.decodeIfPresent(ACLV1.self, forKey: .aclV1) ?? .init()
    }

    var isEmpty: Bool {
        aclV1.chains.isEmpty && aclV1.group.declares.isEmpty && aclV1.group.members.isEmpty
    }
}

struct ACLV1: Codable, Equatable {
    var chains: [ACLChain]
    var group: ACLGroupInfo

    init(chains: [ACLChain] = [], group: ACLGroupInfo = .init()) {
        self.chains = chains
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chains = try container.decodeIfPresent([ACLChain].self, forKey: .chains) ?? []
        group = try container.decodeIfPresent(ACLGroupInfo.self, forKey: .group) ?? .init()
    }

    enum CodingKeys: String, CodingKey {
        case chains
        case group
    }
}

struct ACLChain: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var chainType: ACLChainType
    var description: String
    var enabled: Bool
    var rules: [ACLRule]
    var defaultAction: ACLAction

    enum CodingKeys: String, CodingKey {
        case name
        case chainType = "chain_type"
        case description
        case enabled
        case rules
        case defaultAction = "default_action"
    }

    init(
        name: String = "",
        chainType: ACLChainType = .inbound,
        description: String = "",
        enabled: Bool = true,
        rules: [ACLRule] = [],
        defaultAction: ACLAction = .allow
    ) {
        self.name = name
        self.chainType = chainType
        self.description = description
        self.enabled = enabled
        self.rules = rules
        self.defaultAction = defaultAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        chainType = try container.decodeIfPresent(ACLChainType.self, forKey: .chainType) ?? .unspecified
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        rules = try container.decodeIfPresent([ACLRule].self, forKey: .rules) ?? []
        defaultAction = try container.decodeIfPresent(ACLAction.self, forKey: .defaultAction) ?? .allow
    }
}

struct ACLRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var description: String
    var priority: UInt32
    var enabled: Bool
    var protocolType: ACLProtocol
    var ports: [String]
    var sourceIPs: [String]
    var destinationIPs: [String]
    var sourcePorts: [String]
    var action: ACLAction
    var rateLimit: UInt32
    var burstLimit: UInt32
    var stateful: Bool
    var sourceGroups: [String]
    var destinationGroups: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case priority
        case enabled
        case protocolType = "protocol"
        case ports
        case sourceIPs = "source_ips"
        case destinationIPs = "destination_ips"
        case sourcePorts = "source_ports"
        case action
        case rateLimit = "rate_limit"
        case burstLimit = "burst_limit"
        case stateful
        case sourceGroups = "source_groups"
        case destinationGroups = "destination_groups"
    }

    init(
        name: String = "",
        description: String = "",
        priority: UInt32 = 0,
        enabled: Bool = true,
        protocolType: ACLProtocol = .any,
        ports: [String] = [],
        sourceIPs: [String] = [],
        destinationIPs: [String] = [],
        sourcePorts: [String] = [],
        action: ACLAction = .allow,
        rateLimit: UInt32 = 0,
        burstLimit: UInt32 = 0,
        stateful: Bool = false,
        sourceGroups: [String] = [],
        destinationGroups: [String] = []
    ) {
        self.name = name
        self.description = description
        self.priority = priority
        self.enabled = enabled
        self.protocolType = protocolType
        self.ports = ports
        self.sourceIPs = sourceIPs
        self.destinationIPs = destinationIPs
        self.sourcePorts = sourcePorts
        self.action = action
        self.rateLimit = rateLimit
        self.burstLimit = burstLimit
        self.stateful = stateful
        self.sourceGroups = sourceGroups
        self.destinationGroups = destinationGroups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        priority = try container.decodeIfPresent(UInt32.self, forKey: .priority) ?? 0
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        protocolType = try container.decodeIfPresent(ACLProtocol.self, forKey: .protocolType) ?? .any
        ports = try container.decodeIfPresent([String].self, forKey: .ports) ?? []
        sourceIPs = try container.decodeIfPresent([String].self, forKey: .sourceIPs) ?? []
        destinationIPs = try container.decodeIfPresent([String].self, forKey: .destinationIPs) ?? []
        sourcePorts = try container.decodeIfPresent([String].self, forKey: .sourcePorts) ?? []
        action = try container.decodeIfPresent(ACLAction.self, forKey: .action) ?? .allow
        rateLimit = try container.decodeIfPresent(UInt32.self, forKey: .rateLimit) ?? 0
        burstLimit = try container.decodeIfPresent(UInt32.self, forKey: .burstLimit) ?? 0
        stateful = try container.decodeIfPresent(Bool.self, forKey: .stateful) ?? false
        sourceGroups = try container.decodeIfPresent([String].self, forKey: .sourceGroups) ?? []
        destinationGroups = try container.decodeIfPresent([String].self, forKey: .destinationGroups) ?? []
    }
}

struct ACLGroupInfo: Codable, Equatable {
    var declares: [ACLGroupIdentity]
    var members: [String]

    init(declares: [ACLGroupIdentity] = [], members: [String] = []) {
        self.declares = declares
        self.members = members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        declares = try container.decodeIfPresent([ACLGroupIdentity].self, forKey: .declares) ?? []
        members = try container.decodeIfPresent([String].self, forKey: .members) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case declares
        case members
    }
}

struct ACLGroupIdentity: Codable, Equatable, Identifiable {
    var id = UUID()
    var groupName: String
    var groupSecret: String

    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case groupSecret = "group_secret"
    }

    init(groupName: String = "", groupSecret: String = "") {
        self.groupName = groupName
        self.groupSecret = groupSecret
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? ""
        groupSecret = try container.decodeIfPresent(String.self, forKey: .groupSecret) ?? ""
    }
}
