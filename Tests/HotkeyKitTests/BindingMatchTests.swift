import XCTest
import CoreGraphics
@testable import HotkeyKit

final class BindingMatchTests: XCTestCase {
    // Ctrl + Brightness Up  (NX_KEYTYPE_BRIGHTNESS_UP = 2)
    private let brightnessUp = Binding(
        token: "backlight.up",
        trigger: .mediaKey(2, .control)
    )
    // Ctrl + C  (CGKeyCode 8)
    private let ctrlC = Binding(
        token: "demo.key",
        trigger: .key(8, .control)
    )

    func testMatchesExactMediaKeyAndModifier() {
        let sig = EventSignature(kind: .mediaKey(2), modifiers: .control)
        XCTAssertTrue(brightnessUp.matches(sig))
    }

    func testDoesNotMatchWhenExtraModifierHeld() {
        let sig = EventSignature(kind: .mediaKey(2), modifiers: [.control, .shift])
        XCTAssertFalse(brightnessUp.matches(sig))
    }

    func testDoesNotMatchWhenModifierMissing() {
        let sig = EventSignature(kind: .mediaKey(2), modifiers: [])
        XCTAssertFalse(brightnessUp.matches(sig))
    }

    func testDoesNotMatchWhenMediaCodeDiffers() {
        // Brightness Down (3) must not fire the Up binding.
        let sig = EventSignature(kind: .mediaKey(3), modifiers: .control)
        XCTAssertFalse(brightnessUp.matches(sig))
    }

    func testDoesNotMatchAcrossKinds() {
        // A standard key with code 2 is not the media key with code 2.
        let sig = EventSignature(kind: .key(2), modifiers: .control)
        XCTAssertFalse(brightnessUp.matches(sig))
    }

    func testMatchesExactStandardKey() {
        let sig = EventSignature(kind: .key(8), modifiers: .control)
        XCTAssertTrue(ctrlC.matches(sig))
    }

    func testStandardKeyWrongCodeDoesNotMatch() {
        let sig = EventSignature(kind: .key(9), modifiers: .control)
        XCTAssertFalse(ctrlC.matches(sig))
    }
}
