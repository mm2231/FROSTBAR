// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Constants shared by the app and the privileged helper.
///
/// The mach service name, the launchd label and the helper bundle identifier are
/// literals because launchd cannot expand build settings. If you change them,
/// run `scripts/set_bundle_id.sh` so all three stay in sync.
///
/// The client's team and bundle identifiers are read from the host application's
/// `Info.plist`, never hardcoded: the helper lives inside `FrostBar.app`, so the
/// app bundle is both the source of truth and the thing being verified.
public enum HelperConstants {
    public static let machServiceName = "com.mm2231.frostbar.helper"
    public static let launchDaemonPlistName = "com.mm2231.frostbar.helper.plist"
    public static let daemonSubdirectory = "Contents/Library/LaunchDaemons"
    public static let helperExecutableSubdirectory = "Contents/MacOS"
    public static let protocolVersion = 2

    // MARK: Host application

    /// The `.app` bundle containing the current executable.
    ///
    /// For `FrostBar.app/Contents/MacOS/FrostBarHelper`, `Bundle.main` is the
    /// application bundle. The path walk is a fallback for unusual launch
    /// setups; if both fail the helper fails closed.
    public static var hostAppBundle: Bundle? {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main
        }

        var url = (Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments.first ?? ""))
            .resolvingSymlinksInPath()

        while url.path != "/" {
            if url.pathExtension == "app", let bundle = Bundle(url: url) {
                return bundle
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    static func hostAppInfo(_ key: String) -> String? {
        guard let value = hostAppBundle?.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, value != "$(\(key))"
        else { return nil }
        return value
    }

    public static var clientTeamIdentifier: String {
        hostAppInfo("FrostBarTeamIdentifier") ?? ""
    }

    public static var clientBundleIdentifier: String {
        guard let bundle = hostAppBundle else { return "" }
        // The app bundle's own identifier is the client identity. The helper's
        // Info.plist is not a separate bundle, so do not fall back to its keys.
        return bundle.bundleIdentifier ?? ""
    }

    // MARK: Code signing

    /// Code signing requirement enforced on the XPC listener.
    ///
    /// A placeholder team id (`YOURTEAMID`) or an unreadable app bundle produces
    /// a requirement that can never be satisfied: an unsigned development build
    /// must not silently accept any client.
    public static var clientCodeSigningRequirement: String {
        let team = clientTeamIdentifier
        let bundleID = clientBundleIdentifier
        guard !team.isEmpty, team != "YOURTEAMID", !bundleID.isEmpty else {
            return "identifier \"com.mm2231.frostbar.invalid-client\""
        }
        return "anchor apple generic and identifier \"\(bundleID)\" and certificate leaf[subject.OU] = \"\(team)\""
    }

    /// Version of the containing application, reported in the handshake.
    ///
    /// Both processes live in the same bundle, so this is the app's version
    /// whether it is read by the app or by the helper.
    public static var hostAppVersion: String {
        let short = hostAppInfo("CFBundleShortVersionString") ?? "0.0.0"
        let build = hostAppInfo("CFBundleVersion") ?? "0"
        return "\(short) (\(build))"
    }
}
