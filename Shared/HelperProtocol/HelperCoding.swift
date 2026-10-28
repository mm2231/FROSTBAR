// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Shared JSON coding for the XPC envelope.
public enum HelperCoding {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}
