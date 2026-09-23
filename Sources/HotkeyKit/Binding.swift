// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

/// A trigger mapped to an opaque action `token` the consumer interprets.
/// HotkeyKit never knows what a token means (e.g. "backlight.up").
public struct Binding: Codable, Hashable, Sendable {
    public let token: String
    public var trigger: Trigger
    public var repeatsOnHold: Bool
    public var scope: KeyboardScope

    public init(token: String, trigger: Trigger, repeatsOnHold: Bool = true,
                scope: KeyboardScope = .anyKeyboard) {
        self.token = token
        self.trigger = trigger
        self.repeatsOnHold = repeatsOnHold
        self.scope = scope
    }

    private enum CodingKeys: String, CodingKey { case token, trigger, repeatsOnHold, scope }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        trigger = try c.decode(Trigger.self, forKey: .trigger)
        repeatsOnHold = try c.decodeIfPresent(Bool.self, forKey: .repeatsOnHold) ?? true
        // Bindings encoded before scopes existed listen to every keyboard.
        scope = try c.decodeIfPresent(KeyboardScope.self, forKey: .scope) ?? .anyKeyboard
    }

    /// True iff this binding's trigger exactly matches the incoming event
    /// (same kind, same code, the *exact* tracked modifier set, and a keyboard
    /// the binding's scope admits).
    public func matches(_ signature: EventSignature) -> Bool {
        if scope == .nonAppleKeyboards && signature.fromAppleKeyboard { return false }
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
