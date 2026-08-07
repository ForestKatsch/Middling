# Middling

macOS menu bar app. Hold Fn and a left-click drag becomes a middle-button
drag.

Shift and Control pass through: Fn+Shift+drag is Shift+MMB, Fn+Ctrl+drag is
Ctrl+MMB.

## Requirements

- macOS 13 or later
- Xcode 26 or later to build (the app icon is an Icon Composer document,
  compiled with `actool`)

## Build

```sh
./build.sh
open dist/Middling.app
```

Middling needs Accessibility access. The app walks through granting it on
first launch and starts working as soon as access is granted.

## Signing

`build.sh` signs with the first code signing identity in your keychain, or
falls back to ad-hoc signing with a stable identifier-based designated
requirement so the Accessibility grant survives rebuilds. If the grant ever
gets stuck (granted in System Settings but not working), reset it and grant
again:

```sh
tccutil reset Accessibility com.forestkatsch.Middling
```

## How it works

A session-level `CGEventTap` listens for left mouse down/drag/up. When Fn is
held on mouse-down, events are mutated in place to `otherMouse*` with button
number 2, and the Fn flag is stripped. Releasing Fn mid-drag keeps the drag
middle-button until mouse-up.

## License

MIT
