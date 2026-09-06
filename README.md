# HotkeyKit

<p align="center"><img src="docs/mascot.png" width="160" alt="HotkeyKit mascot, from the Menubarn widget library"></p>

<p align="center">Part of the <a href="https://widgets.nicksmith.software">Menubarn</a> widget library.</p>

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

## Why not a SwiftBar plugin?

HotkeyKit exists for what plugin scripts can never do: own a `CGEventTap` and
intercept, remap or swallow keyboard and media keys system-wide. It pairs with
[StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit), whose README
has the full [comparison with SwiftBar](https://github.com/nicholaspsmith/StatusItemKit#why-not-swiftbar).

## The menu-bar suite

One of the two frameworks behind a suite of macOS menu-bar apps. They share
one build-and-sign script and one installer, and are designed to sit in the
same bar together.

| App | What it does |
|---|---|
| [Claude Usage](https://github.com/nicholaspsmith/claude-usage-menubar) | Claude Code plan limits, resets, and live agent sessions |
| [Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) | Universal Audio Apollo monitor level, plus a UA process watchdog |
| [Battery Time](https://github.com/nicholaspsmith/battery-time-menubar) | Time remaining, power mode, and 24h usage |
| [VPN & DNS](https://github.com/nicholaspsmith/vpn-dns-menubar) | One dot for Mullvad + Tailscale state, with a DNS watcher |
| [Process Monitor](https://github.com/nicholaspsmith/MacOS_Process_Monitor) | Process-count sparkline against the per-UID limit |
| [KeyLight](https://github.com/nicholaspsmith/keylight-menubar) | Ctrl+brightness keys remapped to keyboard backlight |
| [MacRecorder](https://github.com/nicholaspsmith/MacRecorder) | Screen recording with system audio |
| [Media Tracking Killer](https://github.com/nicholaspsmith/media-tracking-killer-menubar) | Kills Apple's media tracking daemons |
| [Download Recycler](https://github.com/nicholaspsmith/download-recycler-menubar) | Sweeps stale files out of ~/Downloads |
| [Curtain](https://github.com/nicholaspsmith/menubar-curtain) | Hides a block of status icons by width, so it cannot strand one |

| Framework | |
|---|---|
| [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit) | Status-item lifecycle, polling, menus, meter icons, the shared Icon picker |
| **HotkeyKit** | CGEventTap engine for intercepting and remapping global keys |

Install the whole suite on a fresh Mac with
[macOS Dev Environment Setup](https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup):

```bash
git clone https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup.git
cd MacOS-Dev-Environment-Setup && ./bootstrap.sh --all
```
