/*
Copyright 2021 Leon Anavi <leon@anavi.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once

#include "config_common.h"

/* USB Device descriptor parameter */
#define VENDOR_ID       0xCEEB
#define PRODUCT_ID      0x0002
#define DEVICE_VER      0x0001
#define MANUFACTURER    ANAVI
#define PRODUCT         Macro Pad 2

/* matrix size */
#define MATRIX_ROWS 1
#define MATRIX_COLS 2

/*
 * Keyboard Matrix Assignments
 *
 * On this board we have direct connection: no diodes.
 */
#define DIRECT_PINS {{ B2, B0 }}

/* Debounce reduces chatter (unintended double-presses) - set 0 if debouncing is not needed */
#define DEBOUNCE 5

#define BACKLIGHT_PIN B1
#define BACKLIGHT_LEVELS 2
#define RGBLIGHT_SLEEP

//#define RGBLED_NUM 2
//#define RGB_DI_PIN B2

// Mouse settings https://docs.qmk.fm/features/mouse_keys
#define MOUSEKEY_WHEEL_DELAY 1                  // (default 10) Delay between pressing a wheel key and wheel movement
#define MOUSEKEY_WHEEL_INTERVAL 40              // (default 40) Time between wheel movements
#define MOUSEKEY_WHEEL_TIME_TO_MAX 20           // (default 80) Time to reach max scroll speed
#define MOUSEKEY_WHEEL_MAX_SPEED 16             // (default 8) Maximum number of scroll steps per scroll action

#define MK_KINETIC_SPEED 
#define MOUSEKEY_WHEEL_INITIAL_MOVEMENTS 16       // (default 16) Initial number of movements of the mouse wheel
#define MOUSEKEY_WHEEL_BASE_MOVEMENTS 32          // (default 32) Maximum number of movements at which acceleration stops
#define MOUSEKEY_WHEEL_ACCELERATED_MOVEMENTS 48   // (default 48) Accelerated wheel movements
#define MOUSEKEY_WHEEL_DECELERATED_MOVEMENTS 8    // (default 8)  Decelerated wheel movements

#define TAPPING_TERM 200

// Save as much space as we can...
#define LAYER_STATE_8BIT
#define NO_ACTION_LAYER
#define NO_ACTION_TAPPING
#define NO_ACTION_ONESHOT
#define NO_RESET

// usbconfig.h overrides
#define USB_CFG_IOPORTNAME B
#define USB_CFG_DMINUS_BIT 3
#define USB_CFG_DPLUS_BIT 4
#define USB_COUNT_SOF 0
#define USB_INTR_CFG PCMSK
#define USB_INTR_CFG_SET (1<<USB_CFG_DPLUS_BIT)
#define USB_INTR_ENABLE_BIT PCIE
#define USB_INTR_PENDING_BIT PCIF
#define USB_INTR_VECTOR SIG_PIN_CHANGE

#define COMBO_COUNT 1
#define COMBO_TERM 500
