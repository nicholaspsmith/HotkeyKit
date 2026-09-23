// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Captures the next key (or media key) the user presses while a prefs window is
/// key, producing a `Trigger`. Uses a *local* monitor (no Accessibility needed)
/// since recording only happens while our own window is focused.
///
/// Note: media keys do not always route to a local monitor; rebinding to a
/// standard key combo is the reliable path. The defaults already cover the
/// media-key case.
public final class TriggerRecorder {
    private var monitor: Any?

    public init() {}

    /// Begin recording. `completion` fires once with the captured trigger, then
    /// recording stops automatically. Pure modifier presses are ignored.
    public func start(_ completion: @escaping (Trigger) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .systemDefined]
        ) { [weak self] event in
            guard let self else { return event }
            guard let trigger = Self.trigger(from: event) else {
                return nil   // swallow modifier-only / non-capturable events
            }
            completion(trigger)
            self.stop()
            return nil       // don't let the captured key act inside the app
        }
    }

    public func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private static func trigger(from event: NSEvent) -> Trigger? {
        let flags = event.cgEvent?.flags ?? []
        switch event.type {
        case .keyDown:
            return .key(event.keyCode, Modifiers(cgFlags: flags, keyCode: event.keyCode))
        case .systemDefined where event.subtype.rawValue == 8:
            let data1 = event.data1
            let mediaCode = Int32((data1 & 0xFFFF_0000) >> 16)
            let keyState = ((data1 & 0x0000_FFFF) & 0xFF00) >> 8
            guard keyState == 0x0A else { return nil }   // press only
            return .mediaKey(mediaCode, Modifiers(cgFlags: flags))
        default:
            return nil
        }
    }
}
