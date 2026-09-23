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
    /// Whether the sending keyboard is Apple's (built-in, or an Apple vendor
    /// ID). Events with no identifiable sender — including ones posted by
    /// software — count as Apple, so a `.nonAppleKeyboards` binding never
    /// fires on them.
    public let fromAppleKeyboard: Bool
    public init(kind: InputKind, modifiers: Modifiers, fromAppleKeyboard: Bool = true) {
        self.kind = kind
        self.modifiers = modifiers
        self.fromAppleKeyboard = fromAppleKeyboard
    }
}

/// Which keyboards a binding listens to.
public enum KeyboardScope: String, Codable, Hashable, Sendable {
    case anyKeyboard
    /// Only keyboards that are not Apple's — for remapping keys that Apple
    /// boards already handle in hardware (F1 → brightness, say) without
    /// stealing fn+F1 from the built-in keyboard.
    case nonAppleKeyboards
}
