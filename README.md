# HotkeyKit

<p align="center"><img src="docs/mascot.png" width="160" alt="HotkeyKit mascot, from Menumon"></p>

<p align="center">Part of <strong><a href="https://menumon.nicksmith.software">Menumon</a></strong>.</p>

A small Swift package for **intercepting global keyboard and media keys** on
macOS and remapping them to your own actions. It owns a `CGEventTap`, matches
incoming events against a declarative set of bindings, and either
**swallows** the original event (so a brightness key no longer changes the
display, say) or passes it through.

It is domain-agnostic: bindings carry opaque action *tokens*, and HotkeyKit
never knows whether a token means "keyboard backlight up" or "snap window
left". [KeyLight](https://github.com/nicholaspsmith/keylight-menubar),
[Monitor Lizard](https://github.com/nicholaspsmith/monitor-lizard-menubar),
[Menu Crane](https://github.com/nicholaspsmith/menu-crane),
[Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) and
[MacRecorder](https://github.com/nicholaspsmith/MacRecorder) use it.

## Requirements

- macOS **13+**
- Swift 5.9
- The host app must be **trusted for Accessibility** for the tap to receive and
  alter events.

## What's in it

| Type | Purpose |
|------|---------|
| `Trigger` | A physical activation: `.key(CGKeyCode, Modifiers)` or `.mediaKey(Int32, Modifiers)` (NX media-key code). `Codable`. |
| `Modifiers` | Normalized `OptionSet` (`control`/`option`/`command`/`shift`/`fn`) with `init(cgFlags:)` / `cgFlags` mapping that ignores caps-lock, numeric-pad and device bits. `init(cgFlags:keyCode:)` also drops `fn` on F1–F20: macOS sets that flag on every F-key event from every keyboard, so write F-key bindings without `.fn`. |
| `Binding` | `Trigger` → opaque `token: String`, plus `repeatsOnHold` (default `true`) and a `scope`: `.anyKeyboard` (default), or `.nonAppleKeyboards` to remap keys Apple boards already handle in hardware without taking fn+F1 from the built-in keyboard. `matches(_:)` requires the modifiers to match exactly. `Codable`. |
| `EventSignature` / `InputKind` | Normalized incoming event (kind, modifiers, `fromAppleKeyboard`), so match logic is pure and unit-tested. |
| `KeyboardRegistry` / `KeyboardIdentity` | Which keyboard sent an event: the HID sender's IORegistry ID (`CGEventField` 87) → its `VendorID` / `Built-In` properties, cached per device. Apple means built-in or vendor `0x05AC` / `0x004C`. An event with no sender (posted by software) counts as Apple, so a `.nonAppleKeyboards` binding never fires on it. |
| `HotkeyTap` | Owns the `CGEventTap` (session tap, head insert). `start()` (returns `false` if the tap cannot be created, usually for lack of Accessibility) / `stop()`, `setBindings(_:)` (safe while running), `isTrusted`, `requestTrust()`. Re-enables itself when the system disables the tap, decodes media keys, suppresses repeats for bindings that don't repeat, and swallows the keyUp of a swallowed press. `onMatch(token) -> Bool` returns `true` to swallow. |
| `TriggerRecorder` | Captures the next key press while your own window is focused and returns it as a `Trigger`. Uses a local event monitor, so it needs no Accessibility; media keys do not always reach a local monitor. |

## Using it

```swift
import HotkeyKit

let tap = HotkeyTap(
    bindings: [
        Binding(token: "backlight.up",   trigger: .mediaKey(2, .control)),  // Ctrl+BrightnessUp
        Binding(token: "backlight.down", trigger: .mediaKey(3, .control)),  // Ctrl+BrightnessDown
        // F1 on a third-party board only; fn+F1 on the MacBook keyboard stays F1.
        Binding(token: "brightness.down", trigger: .key(122, []), scope: .nonAppleKeyboards),
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

`swift test` covers the pure logic: modifier mapping, F-key handling and
binding matching. The tap and recorder are thin OS glue, tested by hand in a
host app, since they need real events and Accessibility permission.

## Why not a SwiftBar plugin?

HotkeyKit exists for what plugin scripts can never do: own a `CGEventTap` and
intercept, remap or swallow keyboard and media keys system-wide. It pairs with
[StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit), whose README
has the full [comparison with SwiftBar](https://github.com/nicholaspsmith/StatusItemKit#why-not-swiftbar).

## The menu-bar suite

One of the two frameworks behind Menumon, a suite of macOS menu-bar apps that
share one build-and-sign script and one installer and sit in the same bar
together.

| App | What it does |
|---|---|
| [Claude Usage](https://github.com/nicholaspsmith/claude-usage-menubar) | Claude Code plan limits, resets, and live agent sessions |
| [Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) | Apollo audio-interface monitor level |
| [Battery Time](https://github.com/nicholaspsmith/battery-time-menubar) | Time remaining, power mode, and 24h usage |
| [VPN & DNS](https://github.com/nicholaspsmith/vpn-dns-menubar) | An iguana for Mullvad + Tailscale state, with a DNS watcher |
| [Mac Daddy](https://github.com/nicholaspsmith/mac-daddy-menubar) | Kills media trackers, trashes stale downloads, reaps hung processes, watches the UA mixer engine, and sweats as your process count climbs |
| [KeyLight](https://github.com/nicholaspsmith/keylight-menubar) | Ctrl+brightness keys remapped to keyboard backlight |
| [Monitor Lizard](https://github.com/nicholaspsmith/monitor-lizard-menubar) | External-monitor brightness, contrast and resolution, Night Shift, and the built-in screen from dimmer than macOS allows to XDR |
| [Homestead](https://github.com/nicholaspsmith/home-assistant-menubar) | Home Assistant dashboards and device controls in the menu |
| [SoundChain](https://github.com/nicholaspsmith/soundchain-menubar) | One chain of Audio Unit effects over all system audio |
| [Menu Crane](https://github.com/nicholaspsmith/menu-crane) | A ⌘Space launcher for apps, arithmetic, unit conversions and emoji |
| [MacRecorder](https://github.com/nicholaspsmith/MacRecorder) | Screen recording with system audio |
| [Barn](https://github.com/nicholaspsmith/menubar-barn) | macOS 26 and earlier only: hides a block of status icons by width (on macOS 27, use System Settings ▸ Menu Bar) |

| Framework | |
|---|---|
| [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit) | Status-item lifecycle, polling, menus, meter and mascot icons, the shared Icon picker |
| **HotkeyKit** | CGEventTap engine for intercepting and remapping global keys |

Install the whole suite on a fresh Mac with
[macOS Dev Environment Setup](https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup):

```bash
git clone https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup.git
cd MacOS-Dev-Environment-Setup && ./bootstrap.sh --all
```

## Releasing

Every push to `main` is a release. Before pushing, add a dated
`## [X.Y.Z] - YYYY-MM-DD` section to the top of [`CHANGELOG.md`](CHANGELOG.md)
(minor for features, patch for fixes; turn a waiting `## [Unreleased]` into
it). When it reaches `main`, GitHub tags `vX.Y.Z` and publishes the section as
a release titled `vX.Y.Z`. Without a new version:

- a push is refused locally by the `pre-push` hook;
- a pull request **cannot merge** — `release / check` is required on `main`;
- a push that reaches `main` anyway fails the release workflow.

The one exception is `[no release]` in the tip commit's message, for changes
nothing a user runs (setup, CI, developer docs): it passes every check with no
version bump and no tag. Never tag or create a release by hand, and never
`gh pr merge --admin` past a failing check — fix the PR. After merging,
`git pull` for the tag. On a fresh clone, re-arm the hook with
`../StatusItemKit/scripts/release/adopt.sh --hooks-only`.
See [StatusItemKit — Releases](https://github.com/nicholaspsmith/StatusItemKit#releases-every-push-is-one) for the whole rule.

## License

Copyright (c) 2026 Nicholas Smith. Licensed under the
[Mozilla Public License 2.0](LICENSE). You may use, modify, sell and
redistribute this software, including inside proprietary products, provided
the copyright notice and license stay on these files and any modified
versions of them are made available under the same license.
