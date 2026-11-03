// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import ApplicationServices
import CoreGraphics

/// Owns a `CGEventTap` that intercepts standard keys and system-defined media
/// keys, matches them against `Binding`s, and lets the consumer swallow them.
///
/// Domain-agnostic: it deals only in opaque action tokens. The consumer's
/// `onMatch` returns `true` to consume the event (e.g. stop the OS from acting
/// on a brightness key) or `false` to pass it through.
///
/// Two observers see what the matcher doesn't: `onKeyDown` gets every key
/// press and `onModifiersChanged` every modifier change (for a "hold ⌘⌥"
/// gesture, say). Neither can swallow anything.
///
/// All access is expected on the main thread (the tap callback is delivered on
/// the main run loop), matching the package's Swift 5 language mode.
public final class HotkeyTap {
    /// Return `true` to swallow the event, `false` to pass it through.
    public typealias MatchHandler = (_ token: String) -> Bool

    /// Called with the held modifiers on every modifier change (a
    /// `flagsChanged` event: ⌘ going down, ⌥ coming up…). The event always
    /// passes through. The tap listens for these only while this is set;
    /// setting or clearing it on a running tap re-creates the tap.
    public var onModifiersChanged: ((Modifiers) -> Void)? {
        didSet {
            guard isRunning, (oldValue == nil) != (onModifiersChanged == nil) else { return }
            stop()
            start()
        }
    }

    /// Called with the keycode of every key press, matched or not, auto-repeats
    /// included, before bindings are matched. Observes only: the press is
    /// still matched, and swallowed or passed through, as usual.
    public var onKeyDown: ((CGKeyCode) -> Void)?

    private var bindings: [Binding]
    private let onMatch: MatchHandler
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let keyboards = KeyboardRegistry()
    private var swallowed = SwallowedKeys()

    public init(bindings: [Binding] = [], onMatch: @escaping MatchHandler) {
        self.bindings = bindings
        self.onMatch = onMatch
    }

    /// Replace the active binding set (safe to call while running).
    public func setBindings(_ newBindings: [Binding]) { bindings = newBindings }

    public var isRunning: Bool { tap != nil }

    /// Whether this process is trusted for Accessibility (required for the tap
    /// to actually receive/alter events).
    public var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompt the user for Accessibility trust (opens the system prompt / pane).
    @discardableResult
    public func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Create and enable the tap. No-op if already running. Returns false if the
    /// tap could not be created (typically: not yet trusted for Accessibility).
    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    /// keyDown (10) + keyUp (11, to swallow the release of a swallowed press)
    /// + NX_SYSDEFINED (14, system-defined media keys), and flagsChanged (12)
    /// only while a modifier observer is set.
    var eventMask: CGEventMask {
        var mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << 14)
        if onModifiersChanged != nil { mask |= 1 << CGEventType.flagsChanged.rawValue }
        return mask
    }

    public func stop() {
        if let port = tap {
            CGEvent.tapEnable(tap: port, enable: false)
            // Dropping the last Swift reference does not tear down the
            // kernel-side tap registration — without an explicit invalidate,
            // every stop() leaves a permanent disabled entry in the session's
            // tap table (visible via CGGetEventTapList).
            CFMachPortInvalidate(port)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    // MARK: - Callback

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        // The system disables taps that take too long; re-arm and move on.
        if type.rawValue == CGEventType.tapDisabledByTimeout.rawValue
            || type.rawValue == CGEventType.tapDisabledByUserInput.rawValue {
            if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
            return passthrough
        }

        let modifiers: Modifiers
        let kind: InputKind
        var isRepeat = false

        if type == .flagsChanged {
            // Before the media-key branch: NSEvent's `subtype` raises on a
            // flagsChanged event.
            onModifiersChanged?(Modifiers(cgFlags: event.flags))
            return passthrough
        } else if type == .keyUp {
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            return swallowed.release(code) ? nil : passthrough
        } else if type == .keyDown {
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            onKeyDown?(code)
            kind = .key(code)
            modifiers = Modifiers(cgFlags: event.flags, keyCode: code)
            isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        } else {
            modifiers = Modifiers(cgFlags: event.flags)
            // System-defined: decode the media-key payload via NSEvent.
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
                return passthrough
            }
            let data1 = ns.data1
            let mediaCode = Int32((data1 & 0xFFFF_0000) >> 16)
            let keyFlags = data1 & 0x0000_FFFF
            let keyState = (keyFlags & 0xFF00) >> 8   // 0x0A == down, 0x0B == up
            guard keyState == 0x0A else { return passthrough }  // act on press only
            isRepeat = (keyFlags & 0x1) == 1
            kind = .mediaKey(mediaCode)
        }

        let signature = EventSignature(
            kind: kind, modifiers: modifiers,
            fromAppleKeyboard: keyboards.isAppleKeyboard(event: event)
        )
        guard let binding = bindings.first(where: { $0.matches(signature) }) else {
            return passthrough
        }

        let shouldFire = !isRepeat || binding.repeatsOnHold
        if shouldFire && !onMatch(binding.token) {
            return passthrough
        }
        // Either the consumer swallowed the press, or a held repeat we chose not
        // to act on: consume it so the captured key never leaks through to the
        // OS mid-hold — and remember to eat the release as well.
        if case .key(let code) = kind { swallowed.swallowed(code) }
        return nil
    }
}

/// Keys whose press the tap swallowed, so their release is swallowed too.
struct SwallowedKeys {
    private var codes: Set<CGKeyCode> = []

    mutating func swallowed(_ code: CGKeyCode) { codes.insert(code) }

    /// True iff this release belongs to a swallowed press (and should be eaten).
    mutating func release(_ code: CGKeyCode) -> Bool { codes.remove(code) != nil }
}
