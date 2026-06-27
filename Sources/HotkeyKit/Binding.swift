/// A trigger mapped to an opaque action `token` the consumer interprets.
/// HotkeyKit never knows what a token means (e.g. "backlight.up").
public struct Binding: Codable, Hashable, Sendable {
    public let token: String
    public var trigger: Trigger
    public var repeatsOnHold: Bool

    public init(token: String, trigger: Trigger, repeatsOnHold: Bool = true) {
        self.token = token
        self.trigger = trigger
        self.repeatsOnHold = repeatsOnHold
    }

    /// True iff this binding's trigger exactly matches the incoming event
    /// (same kind, same code, and the *exact* tracked modifier set).
    public func matches(_ signature: EventSignature) -> Bool {
        switch (trigger, signature.kind) {
        case let (.key(code, mods), .key(inCode)):
            return code == inCode && mods == signature.modifiers
        case let (.mediaKey(code, mods), .mediaKey(inCode)):
            return code == inCode && mods == signature.modifiers
        default:
            return false
        }
    }
}
