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

    /// Like `init(cgFlags:)`, but for a standard-key event. macOS sets the
    /// secondary-fn flag on every event from a key it counts as a function
    /// key: F1–F20 and the navigation keys (the arrows, Home, End, Page Up,
    /// Page Down, Forward Delete and Help), from every keyboard, including
    /// boards with no fn key. On those keycodes the flag says nothing and is
    /// dropped, so ⌘⌥← arrives as ⌘⌥←, not ⌘⌥fn←. Bindings on these keys are
    /// therefore declared without `.fn`.
    public init(cgFlags: CGEventFlags, keyCode: CGKeyCode) {
        self.init(cgFlags: cgFlags)
        if Self.impliesFn(keyCode) { remove(.fn) }
    }

    /// Whether macOS sets the fn flag on every event from this key: an
    /// F-key or a navigation key.
    public static func impliesFn(_ code: CGKeyCode) -> Bool {
        isFunctionKey(code) || isNavigationKey(code)
    }

    /// The ANSI keycodes of F1–F20.
    public static func isFunctionKey(_ code: CGKeyCode) -> Bool {
        functionKeyCodes.contains(code)
    }

    /// The arrows, Home, End, Page Up, Page Down, Forward Delete and Help.
    public static func isNavigationKey(_ code: CGKeyCode) -> Bool {
        navigationKeyCodes.contains(code)
    }

    private static let functionKeyCodes: Set<CGKeyCode> = [
        122, 120, 99, 118, 96,      // F1–F5
        97, 98, 100, 101, 109,      // F6–F10
        103, 111, 105, 107, 113,    // F11–F15
        106, 64, 79, 80, 90,        // F16–F20
    ]

    private static let navigationKeyCodes: Set<CGKeyCode> = [
        123, 124, 125, 126,         // ← → ↓ ↑
        115, 119, 116, 121,         // Home, End, Page Up, Page Down
        117, 114,                   // Forward Delete, Help
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
