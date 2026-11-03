// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import CoreGraphics
@testable import HotkeyKit

/// The tap's callback, fed synthetic events directly (nothing is posted and
/// no tap is created, so no Accessibility is needed).
final class HotkeyTapObserverTests: XCTestCase {
    private func keyEvent(_ code: CGKeyCode, down: Bool = true, flags: CGEventFlags = []) -> CGEvent {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        e.flags = flags
        return e
    }

    private func flagsChanged(_ code: CGKeyCode, flags: CGEventFlags) -> CGEvent {
        let e = keyEvent(code, flags: flags)
        e.type = .flagsChanged
        return e
    }

    // MARK: onModifiersChanged

    func testModifierChangeIsReportedAndPassesThrough() {
        let tap = HotkeyTap { _ in true }
        var seen: [Modifiers] = []
        tap.onModifiersChanged = { seen.append($0) }
        let down = flagsChanged(58, flags: [.maskCommand, .maskAlternate])   // ⌥ joins ⌘
        let result = tap.handle(type: .flagsChanged, event: down)
        XCTAssertTrue(result?.takeUnretainedValue() === down)
        _ = tap.handle(type: .flagsChanged, event: flagsChanged(58, flags: [.maskCommand]))
        _ = tap.handle(type: .flagsChanged, event: flagsChanged(55, flags: []))
        XCTAssertEqual(seen, [[.command, .option], [.command], []])
    }

    func testModifierChangeReportsFnAsHeld() {
        // fn pressed on its own is a real modifier; it is only dropped on key events.
        let tap = HotkeyTap { _ in true }
        var seen: [Modifiers] = []
        tap.onModifiersChanged = { seen.append($0) }
        _ = tap.handle(type: .flagsChanged, event: flagsChanged(63, flags: [.maskSecondaryFn]))
        XCTAssertEqual(seen, [.fn])
    }

    func testModifierChangeWithoutObserverPassesThrough() {
        let tap = HotkeyTap { _ in XCTFail("no binding should fire"); return true }
        let e = flagsChanged(55, flags: [.maskCommand])
        XCTAssertTrue(tap.handle(type: .flagsChanged, event: e)?.takeUnretainedValue() === e)
    }

    func testModifierChangeNeverFiresABinding() {
        // ⌘ going down is not a press of the key bound to ⌘ + its keycode.
        var fired = false
        let tap = HotkeyTap(bindings: [Binding(token: "t", trigger: .key(55, [.command]))]) { _ in fired = true; return true }
        let e = flagsChanged(55, flags: [.maskCommand])
        XCTAssertNotNil(tap.handle(type: .flagsChanged, event: e))
        XCTAssertFalse(fired)
    }

    func testTapListensForModifierChangesOnlyWithAnObserver() {
        let tap = HotkeyTap { _ in true }
        let flagsBit: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let base: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << 14)
        XCTAssertEqual(tap.eventMask, base)
        tap.onModifiersChanged = { _ in }
        XCTAssertEqual(tap.eventMask, base | flagsBit)
        tap.onModifiersChanged = nil
        XCTAssertEqual(tap.eventMask, base)
    }

    // MARK: onKeyDown

    func testKeyDownIsReportedForUnmatchedKeys() {
        let tap = HotkeyTap { _ in true }
        var seen: [CGKeyCode] = []
        tap.onKeyDown = { seen.append($0) }
        let e = keyEvent(53, flags: [.maskCommand, .maskAlternate])   // ⌥⌘⎋
        XCTAssertTrue(tap.handle(type: .keyDown, event: e)?.takeUnretainedValue() === e)
        XCTAssertEqual(seen, [53])
    }

    func testKeyDownIsReportedBeforeTheMatch() {
        var order: [String] = []
        let tap = HotkeyTap(bindings: [Binding(token: "left", trigger: .key(123, [.command, .option]))]) { token in
            order.append(token); return true
        }
        tap.onKeyDown = { _ in order.append("keyDown") }
        _ = tap.handle(type: .keyDown, event: keyEvent(123, flags: [.maskCommand, .maskAlternate]))
        XCTAssertEqual(order, ["keyDown", "left"])
    }

    func testKeyUpIsNotReportedAsKeyDown() {
        let tap = HotkeyTap { _ in true }
        var seen: [CGKeyCode] = []
        tap.onKeyDown = { seen.append($0) }
        _ = tap.handle(type: .keyUp, event: keyEvent(0, down: false))
        XCTAssertEqual(seen, [])
    }

    // MARK: fn on navigation keys, end to end

    func testCmdOptArrowWithImpliedFnMatchesAndIsSwallowed() {
        var fired: [String] = []
        let tap = HotkeyTap(bindings: [Binding(token: "left", trigger: .key(123, [.command, .option]))]) { token in
            fired.append(token); return true
        }
        let down = keyEvent(123, flags: [.maskCommand, .maskAlternate, .maskSecondaryFn])
        XCTAssertNil(tap.handle(type: .keyDown, event: down))
        XCTAssertNil(tap.handle(type: .keyUp, event: keyEvent(123, down: false, flags: [.maskSecondaryFn])))
        XCTAssertEqual(fired, ["left"])
    }

    func testFKeyMatchingIsUnchanged() {
        // KeyLight's ctrl+F1 alias: fn arrives on the event, the binding has none.
        var fired: [String] = []
        let tap = HotkeyTap(bindings: [Binding(token: "backlight.down", trigger: .key(122, .control))]) { token in
            fired.append(token); return true
        }
        XCTAssertNil(tap.handle(type: .keyDown, event: keyEvent(122, flags: [.maskControl, .maskSecondaryFn])))
        XCTAssertEqual(fired, ["backlight.down"])
    }
}
