# HotkeyKit

A small, reusable Swift package for **intercepting global keyboard and media
keys** on macOS and remapping them to your own actions. It owns a `CGEventTap`,
matches incoming events against a declarative set of bindings, and lets you
**swallow** the original event (e.g. stop a brightness key from changing the
display) or pass it through.

Domain-agnostic by design: it deals only in opaque action *tokens* — it never
knows whether a token means "keyboard backlight up" or "snap window left". The
first consumer is [KeyLight](https://github.com/nicholaspsmith/keylight-menubar);
a future window manager can reuse the same engine.

## Requirements

- macOS **13+**
- The host app must be **trusted for Accessibility** for the tap to receive and
  alter events.

## What's in it

| Type | Purpose |
|------|---------|
| `Trigger` | A physical activation: `.key(CGKeyCode, Modifiers)` or `.mediaKey(Int32, Modifiers)` (NX media-key code). `Codable`. |
| `Modifiers` | Normalized `OptionSet` (`control`/`option`/`command`/`shift`/`fn`) with `init(cgFlags:)` / `cgFlags` mapping that ignores caps-lock/numeric-pad/device bits. |
| `Binding` | `Trigger` → opaque `token: String`, plus `repeatsOnHold`. `matches(_:)` does exact-modifier matching. |
| `EventSignature` / `InputKind` | Normalized incoming event, so match logic is pure and unit-tested. |
| `HotkeyTap` | Owns the `CGEventTap` (session tap, head-insert). `start()`/`stop()`, `setBindings(_:)`, `isTrusted`, `requestTrust()`, auto re-arm on system disable, media-key decoding, repeat suppression. `onMatch(token) -> Bool` returns `true` to swallow. |
| `TriggerRecorder` | Captures the next key/media key while a prefs window is focused → a `Trigger` (local monitor, no extra permission). |

## Using it

```swift
import HotkeyKit

let tap = HotkeyTap(
    bindings: [
        Binding(token: "backlight.up",   trigger: .mediaKey(2, .control)),  // Ctrl+BrightnessUp
        Binding(token: "backlight.down", trigger: .mediaKey(3, .control)),  // Ctrl+BrightnessDown
    ],
    onMatch: { token in
        handle(token)        // do the work
        return true          // swallow the original key
    }
)
if !tap.isTrusted { tap.requestTrust() }
tap.start()
```

## Tests

`swift test` covers the pure logic — modifier mapping and binding matching. The
tap and recorder are thin OS glue exercised manually (they need real events and
Accessibility permission).
