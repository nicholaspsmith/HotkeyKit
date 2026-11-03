# Changelog

Every push to `main` is a release. Before pushing, add a `## [X.Y.Z] - YYYY-MM-DD`
section at the top with `- ` entries (minor for features, patch for fixes); if an
`## [Unreleased]` section is waiting, turn it into that section. GitHub tags it
and publishes the section as the release notes; a push or pull request
without one is refused (`[no release]` in the tip commit is the only exception).
Versions follow [Semantic Versioning](https://semver.org/). The full rule:
[StatusItemKit — Releases](https://github.com/nicholaspsmith/StatusItemKit#releases-every-push-is-one).

## [1.1.0] - 2026-11-02
### Added
- `HotkeyTap.onModifiersChanged`: called with the held modifiers on every
  modifier change (`flagsChanged`), for gestures like "hold ⌘⌥". The tap
  listens for modifier changes only while it is set, and never swallows them.
- `HotkeyTap.onKeyDown`: called with the keycode of every key press, matched
  or not, before bindings are matched. Observes only.
- `Modifiers.impliesFn(_:)` and `Modifiers.isNavigationKey(_:)`.
### Changed
- The fn flag is now also dropped on the navigation keys (arrows, Home, End,
  Page Up, Page Down, Forward Delete, Help), as on F1–F20: macOS sets it on
  every event from those keys, so ⌘⌥← now arrives as ⌘⌥←, not ⌘⌥fn←. Write
  their bindings without `.fn`; a binding recorded with it still matches.

## [1.0.0] - 2026-09-26
### Added
- A reusable global key-tap engine: one `CGEventTap` matching keyboard and
  media keys against declarative bindings, each firing an opaque action token
  and either swallowing the original event or passing it through.
- Keyboard scope: bind a key for Apple or non-Apple keyboards only, identified
  per event by the HID sender (`KeyboardRegistry`).
- F-keys: macOS sets the fn flag on every F-key press, so it is stripped on
  F1–F20 and F-key bindings are written without `.fn`.
- A swallowed press also swallows its keyUp.
- Mozilla Public License 2.0.
### Fixed
- `stop()` invalidates the tap's port instead of leaking tap-table entries.
