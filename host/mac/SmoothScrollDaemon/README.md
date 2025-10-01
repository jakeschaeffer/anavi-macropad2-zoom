# SmoothScrollDaemon

A lightweight Swift daemon that listens to the ANAVI Macro Pad 2 RAW HID channel and synthesizes pixel-level scroll events on macOS. This closes the gap between discrete "mouse wheel" deltas and the smooth momentum-based scrolling normally reserved for Apple trackpads.

## Features

- Reads vendor-defined RAW HID reports emitted by the updated QMK firmware.
- Applies easing and momentum so long presses feel like native trackpad scrolling.
- Reconfigures firmware step/interval parameters dynamically without reflashing.
- Posts `kCGScrollEventUnitPixel` events with continuous and momentum flags so macOS applies the smooth scroll pipeline.

## Requirements

- macOS 12 Monterey or newer.
- Accessibility permission (System Settings → Privacy & Security → Accessibility) for the daemon binary.
- ANAVI Macro Pad 2 flashed with the included smooth scrolling firmware (requires `RAW_ENABLE = yes`).

## Build

```bash
swift build --configuration release
```

The compiled binary will be available as:

```
.host/mac/SmoothScrollDaemon/.build/release/smooth-scroll-daemon
```

Copy or symlink the binary somewhere on your `$PATH`, or create a LaunchAgent that executes it on login.

## Run

```bash
./.build/release/smooth-scroll-daemon
```

On first launch macOS will prompt for accessibility permission. Approve it so the daemon can emit synthetic scroll events.

A successful connection log looks like this:

```
[smooth-scroll-daemon] attached RAW HID device: Macro Pad 2
```

## Configuration packets

The daemon pushes an initial configuration packet (`hostStepPixels=6`, `hostIntervalMs=4`) to the firmware so both sides agree on the baseline scrolling cadence. You can adjust these constants in `main.swift` to tune the feel.

```text
Byte 0: 0xA5 (magic)
Byte 1: 0x81 (host configuration message)
Byte 2: vertical step in pixels
Byte 3: interval in milliseconds
Byte 4-31: reserved
```

The firmware can also send configuration messages back to the host using the same format.
