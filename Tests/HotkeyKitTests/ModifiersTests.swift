// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import CoreGraphics
@testable import HotkeyKit

final class ModifiersTests: XCTestCase {
    func testSingleControlFlagMapsToControl() {
        XCTAssertEqual(Modifiers(cgFlags: .maskControl), .control)
    }

    func testCombinedFlagsMapToCombinedModifiers() {
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        XCTAssertEqual(Modifiers(cgFlags: flags), [.control, .option, .command])
    }

    func testIrrelevantFlagsAreIgnored() {
        // Caps lock + numeric pad must not leak into the tracked set.
        let flags: CGEventFlags = [.maskControl, .maskAlphaShift, .maskNumericPad]
        XCTAssertEqual(Modifiers(cgFlags: flags), .control)
    }

    func testNoFlagsMapsToEmpty() {
        XCTAssertEqual(Modifiers(cgFlags: []), [])
    }

    func testCgFlagsRoundTrip() {
        let m: Modifiers = [.control, .shift, .fn]
        XCTAssertEqual(Modifiers(cgFlags: m.cgFlags), m)
    }

    func testCgFlagsContainsExpectedBits() {
        let m: Modifiers = [.control, .command]
        XCTAssertTrue(m.cgFlags.contains(.maskControl))
        XCTAssertTrue(m.cgFlags.contains(.maskCommand))
        XCTAssertFalse(m.cgFlags.contains(.maskAlternate))
    }
}
