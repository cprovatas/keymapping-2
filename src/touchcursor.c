/**
 * Touch Cursor for macOS
 * Replicates the touch cursor style movement under macOS.
 *
 * Special thanks to Thomas Bocek for the starting point for this application.
 * Special thanks to Martin Stone for the inspiration and Touch Cursor source.
 */

#include "keys.h"
#include "queue.h"
#include "binding.h"
#include "emit.h"
#include "touchcursor.h"

// The state machine state
enum states state = idle;


/**
 * Converts input key to touch cursor key.
 */
static int convert(int code)
{
    // return keymap[code];
    return code;
}

/**
 * Processes a key input event. Converts and emits events as necessary.
 */
void processKey(int type, int code, int value)
{
    //printf("processKey: code=%i value=%i state=%i ... ", code, value, state);
    switch (state)
    {
        case idle: // 0
            emit(0, code, value);
            break;

        case delay: // 1
            state = map;
            emit(0, code, value);
            break;

        case map: // 1
            emit(0, code, value);
            break;
    }
    //printf("processKey: state=%i\n", state);
}
