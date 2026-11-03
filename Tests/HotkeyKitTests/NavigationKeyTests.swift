// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import CoreGraphics
@testable import HotkeyKit

/// macOS sets the secondary-fn flag on every navigation-key event (arrows,
/// Home, End, Page Up/Down, Forward Delete, Help) from every keyboard, as on
/// the F-keys, so ⌘⌥← would otherwise arrive as ⌘⌥fn←.
final class NavigationKeyModifierTests: XCTestCase {
    private let navigationKeys: [CGKeyCode] = [123, 124, 125, 126, 115, 119, 116, 121, 117, 114]
    private let cmdOptFn: CGEventFlags = [.maskCommand, .maskAlternate, .maskSecondaryFn]

    func testFnIsDroppedOnEveryNavigationKey() {
        for code in navigationKeys {
            XCTAssertEqual(Modifiers(cgFlags: cmdOptFn, keyCode: code), [.command, .option], "key \(code)")
        }
    }

    func testNavigationKeycodeSet() {
        for code in navigationKeys {
            XCTAssertTrue(Modifiers.isNavigationKey(code), "key \(code)")
            XCTAssertTrue(Modifiers.impliesFn(code), "key \(code)")
            XCTAssertFalse(Modifiers.isFunctionKey(code), "key \(code)")
        }
        XCTAssertFalse(Modifiers.isNavigationKey(8))     // C
        XCTAssertFalse(Modifiers.isNavigationKey(51))    // Delete (backspace)
        XCTAssertFalse(Modifiers.isNavigationKey(122))   // F1
    }

    func testImpliesFnCoversFunctionKeysToo() {
        XCTAssertTrue(Modifiers.impliesFn(122))   // F1
        XCTAssertTrue(Modifiers.impliesFn(111))   // F12
        XCTAssertFalse(Modifiers.impliesFn(8))
    }

    func testFnIsStillKeptOnOrdinaryKeycode() {
        XCTAssertEqual(Modifiers(cgFlags: cmdOptFn, keyCode: 0), [.command, .option, .fn])   // A
    }

    func testNoFnStaysNoFn() {
        XCTAssertEqual(Modifiers(cgFlags: [.maskCommand], keyCode: 123), .command)
    }
}

final class NavigationKeyBindingTests: XCTestCase {
    func testBindingWithoutFnMatchesTheStrippedEvent() {
        let b = Binding(token: "left", trigger: .key(123, [.command, .option]))
        let sig = EventSignature(kind: .key(123), modifiers: Modifiers(cgFlags: [.maskCommand, .maskAlternate, .maskSecondaryFn], keyCode: 123))
        XCTAssertTrue(b.matches(sig))
    }

    func testBindingRecordedWithFnStillMatches() {
        // Recorded before 1.1.0, when the flag reached the recorder.
        let b = Binding(token: "left", trigger: .key(123, [.command, .option, .fn]))
        XCTAssertTrue(b.matches(EventSignature(kind: .key(123), modifiers: [.command, .option])))
    }

    func testFnStillCountsInBindingsOnOtherKeys() {
        let b = Binding(token: "m", trigger: .key(46, [.command, .fn]))
        XCTAssertFalse(b.matches(EventSignature(kind: .key(46), modifiers: [.command])))
        XCTAssertTrue(b.matches(EventSignature(kind: .key(46), modifiers: [.command, .fn])))
    }

    func testFKeyBindingMatchingIsUnchanged() {
        // F-key bindings were never fn-lenient; an fn F-key binding still never fires.
        let b = Binding(token: "f1", trigger: .key(122, [.control, .fn]))
        XCTAssertFalse(b.matches(EventSignature(kind: .key(122), modifiers: [.control])))
    }

    func testOtherModifiersStillMatchExactly() {
        let b = Binding(token: "left", trigger: .key(123, [.command, .option]))
        XCTAssertFalse(b.matches(EventSignature(kind: .key(123), modifiers: [.command, .option, .shift])))
        XCTAssertFalse(b.matches(EventSignature(kind: .key(123), modifiers: [.command])))
    }
}
