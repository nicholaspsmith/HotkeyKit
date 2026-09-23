// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import CoreGraphics
@testable import HotkeyKit

/// macOS sets the secondary-fn flag on every function-key event (F1–F20) from
/// every keyboard, including boards that have no fn key. On those keycodes the
/// flag carries no information, so the tracked modifiers must drop it.
final class FunctionKeyModifierTests: XCTestCase {
    private let ctrlFn: CGEventFlags = [.maskControl, .maskSecondaryFn]

    func testFnIsDroppedOnFunctionKeycode() {
        // F1 = 122
        XCTAssertEqual(Modifiers(cgFlags: ctrlFn, keyCode: 122), .control)
    }

    func testFnIsDroppedOnF12() {
        XCTAssertEqual(Modifiers(cgFlags: [.maskSecondaryFn], keyCode: 111), [])
    }

    func testFnIsKeptOnOrdinaryKeycode() {
        // fn+C really is fn+C.
        XCTAssertEqual(Modifiers(cgFlags: ctrlFn, keyCode: 8), [.control, .fn])
    }

    func testFunctionKeycodeSet() {
        for code: CGKeyCode in [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111] {
            XCTAssertTrue(Modifiers.isFunctionKey(code), "F-key \(code)")
        }
        XCTAssertFalse(Modifiers.isFunctionKey(8))
        XCTAssertFalse(Modifiers.isFunctionKey(53))   // Esc
    }
}

/// A binding can be limited to keyboards that are not Apple's, so a remap of
/// F1 on a third-party board leaves fn+F1 on the MacBook keyboard alone.
final class KeyboardScopeTests: XCTestCase {
    private let anyF1 = Binding(token: "t", trigger: .key(122, []))
    private let otherF1 = Binding(token: "t", trigger: .key(122, []), scope: .nonAppleKeyboards)

    func testDefaultScopeIsAnyKeyboard() {
        XCTAssertEqual(anyF1.scope, .anyKeyboard)
    }

    func testSignatureDefaultsToAppleKeyboard() {
        // Events with no identifiable sender (synthetic ones included) count as
        // Apple, so a non-Apple-only binding never fires on them.
        XCTAssertTrue(EventSignature(kind: .key(122), modifiers: []).fromAppleKeyboard)
    }

    func testAnyKeyboardMatchesBoth() {
        XCTAssertTrue(anyF1.matches(EventSignature(kind: .key(122), modifiers: [], fromAppleKeyboard: true)))
        XCTAssertTrue(anyF1.matches(EventSignature(kind: .key(122), modifiers: [], fromAppleKeyboard: false)))
    }

    func testNonAppleScopeSkipsAppleKeyboard() {
        XCTAssertFalse(otherF1.matches(EventSignature(kind: .key(122), modifiers: [], fromAppleKeyboard: true)))
    }

    func testNonAppleScopeMatchesOtherKeyboard() {
        XCTAssertTrue(otherF1.matches(EventSignature(kind: .key(122), modifiers: [], fromAppleKeyboard: false)))
    }

    func testScopeSurvivesJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(otherF1)
        XCTAssertEqual(try JSONDecoder().decode(Binding.self, from: data), otherF1)
    }

    func testBindingWithoutScopeKeyDecodesAsAnyKeyboard() throws {
        let legacy = #"{"token":"t","trigger":{"key":{"_0":122,"_1":0}},"repeatsOnHold":true}"#
        let decoded = try JSONDecoder().decode(Binding.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.scope, .anyKeyboard)
    }
}

/// Deciding "is this an Apple keyboard" from the HID service's registry
/// properties. The lookup itself needs IOKit; the decision is pure.
final class KeyboardIdentityTests: XCTestCase {
    func testBuiltInIsApple() {
        XCTAssertTrue(KeyboardIdentity.isApple(vendorID: 0, builtIn: true))
    }

    func testAppleVendorIDsAreApple() {
        XCTAssertTrue(KeyboardIdentity.isApple(vendorID: 0x05AC, builtIn: false))   // USB Apple
        XCTAssertTrue(KeyboardIdentity.isApple(vendorID: 0x004C, builtIn: false))   // Bluetooth Apple
    }

    func testOtherVendorIsNotApple() {
        XCTAssertFalse(KeyboardIdentity.isApple(vendorID: 0x000E, builtIn: false))
        XCTAssertFalse(KeyboardIdentity.isApple(vendorID: nil, builtIn: false))
    }

    func testMissingSenderCountsAsApple() {
        // Sender ID 0: no device behind the event (e.g. posted by software).
        let registry = KeyboardRegistry()
        XCTAssertTrue(registry.isAppleKeyboard(senderID: 0))
    }
}

/// When a keyDown is swallowed, its keyUp must be swallowed too, or apps see a
/// release with no press.
final class SwallowedKeysTests: XCTestCase {
    func testReleaseOfSwallowedKeyIsSwallowedOnce() {
        var held = SwallowedKeys()
        held.swallowed(122)
        XCTAssertTrue(held.release(122))
        XCTAssertFalse(held.release(122))
    }

    func testReleaseOfUnswallowedKeyPassesThrough() {
        var held = SwallowedKeys()
        XCTAssertFalse(held.release(120))
    }
}
