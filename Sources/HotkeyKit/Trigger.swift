// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import CoreGraphics

/// A physical activation: either a standard key (by `CGKeyCode`) or a
/// system-defined media key (by its NX media-key code), plus modifiers.
public enum Trigger: Codable, Hashable, Sendable {
    case key(CGKeyCode, Modifiers)
    case mediaKey(Int32, Modifiers)

    public var modifiers: Modifiers {
        switch self {
        case .key(_, let m), .mediaKey(_, let m): return m
        }
    }
}

/// A normalized incoming input event, produced by the tap and matched against
/// bindings. Pure value type so matching is unit-testable without real events.
public enum InputKind: Hashable, Sendable {
    case key(CGKeyCode)
    case mediaKey(Int32)
}

public struct EventSignature: Hashable, Sendable {
    public let kind: InputKind
    public let modifiers: Modifiers
    public init(kind: InputKind, modifiers: Modifiers) {
        self.kind = kind
        self.modifiers = modifiers
    }
}
