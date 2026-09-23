// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import CoreGraphics

/// The keyboard modifier keys HotkeyKit tracks for matching. Deliberately a
/// small, normalized subset of `CGEventFlags` (ignores caps-lock, numeric-pad,
/// and device-dependent bits) so equality comparison is meaningful.
public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1 << 0)
    public static let option  = Modifiers(rawValue: 1 << 1)
    public static let command = Modifiers(rawValue: 1 << 2)
    public static let shift   = Modifiers(rawValue: 1 << 3)
    public static let fn      = Modifiers(rawValue: 1 << 4)

    /// Extract the tracked modifiers from a live event's flags.
    public init(cgFlags: CGEventFlags) {
        var m: Modifiers = []
        if cgFlags.contains(.maskControl)      { m.insert(.control) }
        if cgFlags.contains(.maskAlternate)    { m.insert(.option) }
        if cgFlags.contains(.maskCommand)      { m.insert(.command) }
        if cgFlags.contains(.maskShift)        { m.insert(.shift) }
        if cgFlags.contains(.maskSecondaryFn)  { m.insert(.fn) }
        self = m
    }

    /// Like `init(cgFlags:)`, but for a standard-key event: macOS sets the
    /// secondary-fn flag on every function-key event (F1–F20) from every
    /// keyboard, including boards with no fn key, so on those keycodes the
    /// flag says nothing and is dropped. Bindings on F-keys are therefore
    /// declared without `.fn`.
    public init(cgFlags: CGEventFlags, keyCode: CGKeyCode) {
        self.init(cgFlags: cgFlags)
        if Self.isFunctionKey(keyCode) { remove(.fn) }
    }

    /// The ANSI keycodes of F1–F20.
    public static func isFunctionKey(_ code: CGKeyCode) -> Bool {
        functionKeyCodes.contains(code)
    }

    private static let functionKeyCodes: Set<CGKeyCode> = [
        122, 120, 99, 118, 96,      // F1–F5
        97, 98, 100, 101, 109,      // F6–F10
        103, 111, 105, 107, 113,    // F11–F15
        106, 64, 79, 80, 90,        // F16–F20
    ]

    /// Reconstruct `CGEventFlags` containing only the tracked modifiers.
    public var cgFlags: CGEventFlags {
        var f: CGEventFlags = []
        if contains(.control) { f.insert(.maskControl) }
        if contains(.option)  { f.insert(.maskAlternate) }
        if contains(.command) { f.insert(.maskCommand) }
        if contains(.shift)   { f.insert(.maskShift) }
        if contains(.fn)      { f.insert(.maskSecondaryFn) }
        return f
    }
}
