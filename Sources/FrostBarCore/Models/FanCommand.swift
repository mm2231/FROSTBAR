// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// A command crossing the domain/helper boundary.
///
/// The helper never accepts raw SMC keys: only these cases are on the wire.
public enum FanCommand: Sendable, Equatable {
    case automatic
    case fixed(RPM)
    case perFan([String: RPM])
    case limits(fan: FanID, minimum: RPM?, maximum: RPM?)
}

extension FanCommand: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case rpm
        case values
        case fan
        case minimum
        case maximum
    }

    private enum Kind: String, Codable {
        case automatic
        case fixed
        case perFan
        case limits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .automatic:
            self = .automatic
        case .fixed:
            self = .fixed(try container.decode(RPM.self, forKey: .rpm))
        case .perFan:
            self = .perFan(try container.decode([String: RPM].self, forKey: .values))
        case .limits:
            self = .limits(
                fan: try container.decode(FanID.self, forKey: .fan),
                minimum: try container.decodeIfPresent(RPM.self, forKey: .minimum),
                maximum: try container.decodeIfPresent(RPM.self, forKey: .maximum)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .automatic:
            try container.encode(Kind.automatic.rawValue, forKey: .type)
        case let .fixed(rpm):
            try container.encode(Kind.fixed.rawValue, forKey: .type)
            try container.encode(rpm, forKey: .rpm)
        case let .perFan(values):
            try container.encode(Kind.perFan.rawValue, forKey: .type)
            try container.encode(values, forKey: .values)
        case let .limits(fan, minimum, maximum):
            try container.encode(Kind.limits.rawValue, forKey: .type)
            try container.encode(fan, forKey: .fan)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
        }
    }
}
