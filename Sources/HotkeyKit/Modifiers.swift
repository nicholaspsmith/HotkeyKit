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
