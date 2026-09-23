// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import CoreGraphics
import IOKit

/// Decides whether a keyboard is Apple's from its HID service properties.
public enum KeyboardIdentity {
    /// Apple's USB vendor ID and its Bluetooth SIG company ID.
    private static let appleVendorIDs: Set<Int> = [0x05AC, 0x004C]

    public static func isApple(vendorID: Int?, builtIn: Bool) -> Bool {
        if builtIn { return true }
        guard let vendorID else { return false }
        return appleVendorIDs.contains(vendorID)
    }
}

/// Answers "did an Apple keyboard send this event?" for a `CGEvent`'s HID
/// sender, and remembers the answer per device. The sender is the IORegistry
/// entry ID of the HID event service (`CGEventField` 87, undocumented but
/// stable since 10.x); its `VendorID` and `Built-In` properties decide.
public final class KeyboardRegistry {
    /// `CGEventField` raw value carrying the sending HID service's registry ID.
    public static let senderIDField = CGEventField(rawValue: 87)!

    private var cache: [UInt64: Bool] = [:]

    public init() {}

    public func isAppleKeyboard(event: CGEvent) -> Bool {
        isAppleKeyboard(senderID: UInt64(bitPattern: event.getIntegerValueField(Self.senderIDField)))
    }

    /// Sender 0 means no device is behind the event (posted by software, or a
    /// build of macOS that stopped filling the field): treated as Apple so
    /// device-restricted bindings fail closed.
    public func isAppleKeyboard(senderID: UInt64) -> Bool {
        guard senderID != 0 else { return true }
        if let known = cache[senderID] { return known }
        let answer = Self.lookup(senderID: senderID)
        cache[senderID] = answer
        return answer
    }

    /// Forget cached answers (e.g. after a keyboard is unplugged and another
    /// one is assigned the same registry ID — IDs are not reused in practice,
    /// but the cache is cheap to rebuild).
    public func reset() { cache.removeAll() }

    private static func lookup(senderID: UInt64) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(senderID))
        guard service != 0 else { return true }   // unknown device: fail closed
        defer { IOObjectRelease(service) }
        let vendor = property("VendorID", of: service) as? Int
        let builtIn = (property("Built-In", of: service) as? Bool) ?? false
        return KeyboardIdentity.isApple(vendorID: vendor, builtIn: builtIn)
    }

    private static func property(_ key: String, of service: io_service_t) -> Any? {
        IORegistryEntrySearchCFProperty(
            service, kIOServicePlane, key as CFString, kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        )
    }
}
