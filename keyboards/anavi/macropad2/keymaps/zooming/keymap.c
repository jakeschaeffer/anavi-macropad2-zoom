#include QMK_KEYBOARD_H

#ifdef RAW_ENABLE
#    include "raw_hid.h"
#else
#    error "RAW_ENABLE must be set for the smooth scrolling keymap"
#endif

// Raw HID payload layout (32 bytes)
// Byte 0 : 0xA5 magic header
// Byte 1 : message type (0x01 device->host scroll, 0x81 host->device config)
// Byte 2-3 : int16 vertical delta in pixels (little endian)
// Byte 4-5 : int16 horizontal delta in pixels (little endian)
// Byte 6 : flags (bit0: continuous gesture)
// Byte 7 : nominal step size suggested by firmware (pixels)
// Byte 8-31 : reserved / future use

enum custom_keycodes {
    SCROLL_UP = SAFE_RANGE,
    SCROLL_DOWN,
};

enum {
    SCROLL_MSG_MAGIC = 0xA5,
    SCROLL_MSG_SCROLL = 0x01,
    SCROLL_MSG_CONFIG = 0x81,
};

#define SCROLL_RAW_BYTES 32
#define DEFAULT_SCROLL_STEP 24
#define DEFAULT_SCROLL_INTERVAL 5

static volatile bool scroll_up_active = false;
static volatile bool scroll_down_active = false;
static uint8_t scroll_step_pixels = DEFAULT_SCROLL_STEP;
static uint8_t scroll_interval_ms = DEFAULT_SCROLL_INTERVAL;
static uint16_t last_scroll_tick = 0;

static void send_scroll_report(int16_t vertical_delta, int16_t horizontal_delta, bool continuous) {
    if (vertical_delta == 0 && horizontal_delta == 0) {
        return;
    }

    uint8_t report[SCROLL_RAW_BYTES] = {0};
    report[0] = SCROLL_MSG_MAGIC;
    report[1] = SCROLL_MSG_SCROLL;
    report[2] = (uint8_t)(vertical_delta & 0xFF);
    report[3] = (uint8_t)((vertical_delta >> 8) & 0xFF);
    report[4] = (uint8_t)(horizontal_delta & 0xFF);
    report[5] = (uint8_t)((horizontal_delta >> 8) & 0xFF);
    report[6] = continuous ? 0x01 : 0x00;
    report[7] = scroll_step_pixels;

    raw_hid_send(report, SCROLL_RAW_BYTES);
}

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT(
        SCROLL_UP, SCROLL_DOWN
    )
};

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case SCROLL_UP:
            scroll_up_active = record->event.pressed;
            if (record->event.pressed) {
                last_scroll_tick = timer_read();
                send_scroll_report(-((int16_t)scroll_step_pixels), 0, true);
            }
            return false;
        case SCROLL_DOWN:
            scroll_down_active = record->event.pressed;
            if (record->event.pressed) {
                last_scroll_tick = timer_read();
                send_scroll_report(scroll_step_pixels, 0, true);
            }
            return false;
        default:
            return true;
    }
}

void matrix_scan_user(void) {
    if (!scroll_up_active && !scroll_down_active) {
        return;
    }

    if (timer_elapsed(last_scroll_tick) < scroll_interval_ms) {
        return;
    }

    last_scroll_tick = timer_read();

    int16_t delta = 0;
    if (scroll_up_active) {
        delta -= scroll_step_pixels;
    }
    if (scroll_down_active) {
        delta += scroll_step_pixels;
    }

    if (delta != 0) {
        send_scroll_report(delta, 0, true);
    }
}

#if defined(RAW_ENABLE)
void raw_hid_receive(uint8_t *data, uint8_t length) {
    if (length < 4) {
        return;
    }

    if (data[0] != SCROLL_MSG_MAGIC || data[1] != SCROLL_MSG_CONFIG) {
        return;
    }

    uint8_t requested_step = data[2];
    uint8_t requested_interval = data[3];

    if (requested_step >= 2) {
        scroll_step_pixels = requested_step;
    }

    if (requested_interval >= 1) {
        scroll_interval_ms = requested_interval;
    }
}
#endif
