# SmoothScrollConfigurator

A lightweight SwiftUI macOS app that edits the SmoothScrollDaemon configuration file and restarts the daemon so you can dial in scrolling feel in real time.

## Features

- Adjust step size, interval, damping, maximum per-frame delta, and minimum output magnitude via sliders/steppers.
- Writes `~/Library/Application Support/SmoothScrollDaemon/config.json` which the daemon reads on launch.
- Terminates any running daemon instances and relaunches the binary from `.build/release/smooth-scroll-daemon`.

## Build

```bash
cd host/mac/SmoothScrollConfigurator
swift build -c release
```

## Run

```bash
swift run SmoothScrollConfigurator
```

Alternatively, open the package in Xcode to run the UI with the live preview tools.

> **Note:** The configurator expects the daemon binary to live at
> `~/Active/Development/General_Projects/anavi/host/mac/SmoothScrollDaemon/.build/release/smooth-scroll-daemon`. Update the path in `ConfigStore.restartDaemon()` if your build output differs.
