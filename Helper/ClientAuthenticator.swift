// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import Security

/// Verifies that a connecting process is the signed FrostBar app.
///
/// `NSXPCConnection` exposes the peer pid but not its audit token, so the code
/// signature is resolved from the pid with `SecCodeCopyGuestWithAttributes` and
/// checked against a requirement built from the host app's own identifiers.
/// The check runs once per connection, before the connection is resumed; a
/// rejected peer never reaches the exported object.
struct ClientAuthenticator {
    private let requirement: SecRequirement?

    init(requirementString: String = HelperConstants.clientCodeSigningRequirement) {
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(requirementString as CFString, [], &requirement)
        self.requirement = status == errSecSuccess ? requirement : nil
    }

    var hasUsableRequirement: Bool {
        requirement != nil
    }

    func isAuthorized(_ connection: NSXPCConnection) -> Bool {
        guard let requirement else { return false }
        let pid = connection.processIdentifier
        guard pid > 0 else { return false }

        var code: SecCode?
        let attributes = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code
        else {
            return false
        }

        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
