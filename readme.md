A keyboard GUI component for [Recoil](https://github.com/beyond-all-reason/spring)/[MasterFramework](https://github.com/masterbel2/gui-master-framework).

## Using Lua-Keyboard

Keyboard is loaded at layer `-1`, above MasterFramework at `-2`. Widgets depending on this keyboard must be located at `0` or higher, or else delay initialisation.

Keyboard registers the function `WG.MasterGUIKeyboard` which will return the keyboard component.

## Behaviour and customisation

Keyboard provides a few properties and methods:
 - `keyboard.mainKeypad`: the main alphanumeric `KeyPad` of the keyboard.
 - `keyboard.escapeKeypad`: the keypad containing only the escape key.
 - `keyboard.arrowKeypad`: the keypad containing the four arrow keys (up, down, left, right).
 - `keyboard.navigationKeypad`: the keypad traditionally above the arrow keypad, including insert, home, end, delete, page up, and page down.
 - `keyboard.numericKeypad`: then keypad containing the numberic keys, including num lock.
 - `keyboard.fKeypad`: the keypad including F1-F12.
 - `keyboard.operationKeypad`: the keypad including print screen, scroll lock, and pause/break.
 - `keyboard.uiKeys`: a table of all keys on the keyboard, keyed by their keycode. Each of these keys provides the following interface:
   - `uiKey._keyCode`: the SDL1 keyCode matching the key
   - `

Currently, for testing purposes, the keyboard colours keys red when clicked by the user. This functionality is planned to be removed from the base keyboard, in favour of something much more flexible.

## Navigating the project

The main file is `LuaUI/Widgets/gui_keyboard.lua`. Tables of keycodes and scan codes are provided in the folder `LuaUI/Widgets/keyCodes/`.