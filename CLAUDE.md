# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains two main firmware projects:

1. **QMK Firmware** (`qmk_firmware/`) - Complete QMK firmware codebase specifically configured for ANAVI MacroPad2 keyboards
2. **Micronucleus** (`micronucleus/`) - USB bootloader for AVR ATtiny microcontrollers

## Project Goal

The primary goal of this project is to configure the 2-key ANAVI MacroPad2 to perform **global zoom in and zoom out on macOS**. This takes advantage of macOS accessibility settings using the combination of a modifier key and scroll gesture to zoom in/out.

**Current Setup:**
- The macropad is configured to use **Cmd** as the modifier key
- Key 1: Zoom In (Cmd+Alt+=)
- Key 2: Zoom Out (Cmd+Alt+-)
- The `zooming` keymap is the active configuration
- The project currently works as intended

This setup allows for quick accessibility zoom control without needing to access the full keyboard, making it ideal for presentations, accessibility needs, or detailed work requiring frequent zoom adjustments.

## Common Commands

### QMK Firmware Commands

The project uses the QMK CLI tool for building and managing keyboard firmware:

```bash
# Navigate to QMK directory
cd qmk_firmware/

# Build firmware for ANAVI MacroPad2 (various keymaps available)
make anavi/macropad2:default
make anavi/macropad2:copypaste
make anavi/macropad2:scroll
make anavi/macropad2:zooming  # Primary keymap for this project

# Flash the zoom keymap to device (primary use case)
make anavi/macropad2:zooming:flash

# Flash other keymaps if needed
make anavi/macropad2:default:flash

# Clean build artifacts
make clean

# Lint and format code
make lint
./bin/qmk cformat
./bin/qmk pyformat

# Run tests
make test
./bin/qmk pytest
```

### Micronucleus Commands

The micronucleus bootloader uses make with specific configurations:

```bash
# Navigate to micronucleus directory
cd micronucleus/

# Build with specific configuration
make CONFIG=<config_name>
make CONFIG=t85_default

# Configure fuses and flash bootloader
make CONFIG=<config_name> fuse
make CONFIG=<config_name> flash

# Clean build artifacts
make clean
```

## Architecture

### QMK Firmware Structure

- `keyboards/` - Hardware-specific keyboard definitions
- `lib/python/qmk/` - Python CLI framework and utilities
- `quantum/` - Core QMK framework code
- `tmk_core/` - Low-level keyboard matrix and USB handling
- `users/` - User-specific keymap code
- `layouts/` - Community keyboard layouts

### Key Components

- **CLI Tool**: `bin/qmk` - Python-based command line interface
- **Build System**: Make-based build system with modular configuration
- **Python Libraries**: Located in `lib/python/qmk/` with full CLI framework
- **Hardware Support**: Extensive keyboard support including ANAVI MacroPad2

### ANAVI MacroPad2 Keymaps

This repository contains pre-built firmware for ANAVI MacroPad2 with several keymap variants:
- `default` - Standard default keymap
- `copypaste` - Copy/paste focused keymap
- `scroll` - Scrolling focused keymap
- **`zooming` - Zoom controls keymap (PRIMARY USE CASE)**
  - Key 1: Zoom In (Cmd+Alt+=)
  - Key 2: Zoom Out (Cmd+Alt+-)
  - Optimized for macOS accessibility zoom
  - Located at: `qmk_firmware/keyboards/anavi/macropad2/keymaps/zooming/keymap.c`

### macOS Accessibility Setup

For the zoom functionality to work, ensure macOS accessibility zoom is enabled:
1. System Preferences → Accessibility → Zoom
2. Enable "Use keyboard shortcuts to zoom"
3. Set modifier key to "Option + Command" (Cmd+Alt)
4. The macropad will then trigger zoom in/out using these shortcuts

### Micronucleus Architecture

- `firmware/` - Bootloader firmware source
- `commandline/` - Host-side upload utility
- `firmware/configurations/` - Device-specific configurations
- Configuration-based build system supporting various ATtiny microcontrollers

## Development Setup

### QMK Prerequisites

Python 3.8+ required with dependencies listed in `requirements.txt`:
- milc (CLI framework)
- hjson, jsonschema (configuration parsing)
- pyusb, hid (USB device communication)

### Build Environment

QMK supports multiple build environments:
- Native builds using AVR-GCC toolchain
- Nix environment (`shell.nix` provided)
- Docker container (`Dockerfile` provided)

The build system automatically detects and uses the `qmk` CLI if available in PATH, otherwise falls back to `bin/qmk`.