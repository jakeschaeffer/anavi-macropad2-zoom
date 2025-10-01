# Smooth scrolling keymap

This keymap repurposes the two keys on the ANAVI Macro Pad 2 to stream high-frequency scroll deltas over QMK's RAW HID interface instead of sending standard keyboard shortcuts. Pair it with the `SmoothScrollDaemon` macOS helper to obtain pixel-level scrolling that feels close to Apple's trackpads.

## Firmware features

- `RAW_ENABLE = yes` in `rules.mk` exposes a vendor-defined HID interface.
- Holding the left key emits upward scroll motion, the right key emits downward motion.
- The firmware streams `0xA5`-prefixed 32-byte packets at a configurable interval (default 5 ms) so the host can smooth and interpret momentum.
- Host configuration packets (type `0x81`) can adjust the step size or interval without reflashing.

## Build & flash

```bash
qmk compile -kb anavi/macropad2 -km zooming
micronucleus --run .build/anavi_macropad2_zooming.hex
```

Replace the flashing command with your preferred workflow if you already have one set up.

## Host integration

Flash the firmware, then build and run the macOS helper located at `host/mac/SmoothScrollDaemon`. When both are active, scrolling through long documents should feel fluid instead of jumpy.
