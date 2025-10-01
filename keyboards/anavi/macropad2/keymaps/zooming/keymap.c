#include QMK_KEYBOARD_H

// Define custom keycodes (optional, but can be useful for more complex behaviors)
enum custom_keycodes {
    ZOOM_IN = SAFE_RANGE,
    ZOOM_OUT,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT(
    ZOOM_IN, ZOOM_OUT
  )
};

// Optional: You can keep the process_record_user function for any other custom behavior
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case ZOOM_IN:
            if (record->event.pressed) {
                register_code(KC_LGUI);
                register_code(KC_LALT);
                register_code(KC_EQUAL);
            } else {
                unregister_code(KC_EQUAL);
                unregister_code(KC_LALT);
                unregister_code(KC_LGUI);
            }
            return false;           
        case ZOOM_OUT:
            if (record->event.pressed) {
                register_code(KC_LGUI);
                register_code(KC_LALT);
                register_code(KC_MINUS);
            } else {
                unregister_code(KC_MINUS);
                unregister_code(KC_LALT);
                unregister_code(KC_LGUI);
            }
            return false;
        default:
            return true;
    }
}

void matrix_scan_user(void) {
    static uint8_t zoom_counter = 0;
    static bool zooming_in = false;
    static bool zooming_out = false;

    zoom_counter++;
    if (zoom_counter >= 10) {  // Adjust this value to change repeat rate
        zoom_counter = 0;
        if (get_mods() & MOD_BIT(KC_LGUI) && get_mods() & MOD_BIT(KC_LALT)) {
            if (zooming_in) {
                tap_code(KC_EQUAL);
            } else if (zooming_out) {
                tap_code(KC_MINUS);
            }
        }
    }

    // Update zooming state
    zooming_in = (get_mods() & MOD_BIT(KC_LGUI)) && (get_mods() & MOD_BIT(KC_LALT)) && (get_mods() & MOD_BIT(KC_LSFT));
    zooming_out = (get_mods() & MOD_BIT(KC_LGUI)) && (get_mods() & MOD_BIT(KC_LALT)) && !(get_mods() & MOD_BIT(KC_LSFT));
}

// ... existing code ...
