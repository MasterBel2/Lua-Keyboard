function widget:GetInfo()
	return {
        name      = "Keyboard",
        desc      = "Provides WG.MasterGUIKeyboard\n",
        author    = "MasterBel2",
        date      = "October 2023",
        license   = "GNU GPL, v2",
        layer     = -1, -- must be in front
        enabled   = true, --enabled by default
	}
end

local requiredFrameworkVersion = "Dev"

local OperationKeys
local FKeys
local MainKeypad
local EscapeKey
local NavigationKeys
local ArrowKeys
local NumericKeypad

local mainKeypad
local escapeKeypad
local arrowKeypad
local navigationKeypad
local numericKeypad
local fKeypad
local operationKeypad

local keyCodes
local keyNames
local keyCodeTypes

local imap
-- Creates a new table composed of the results of calling a function on each key-value pair of the original table.
local map
-- Returns an array containing all elements in the provided arrays, in the reverse order than provided.
local joinArrays

function widget:Initialize()
    MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
    if not MasterFramework then
        error("MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end

    table = MasterFramework.table

    imap = MasterFramework.table.imap
    map = MasterFramework.table.map
    joinArrays = MasterFramework.table.joinArrays
end


------------------------------------------------------------------------------------------------------------
-- Interface Component Definitions
------------------------------------------------------------------------------------------------------------

-- Constrains the width of its body to the width of the provided GeometryTarget.
local function MatchWidth(target, body)
    local matchWidth = {}

    function matchWidth:LayoutChildren()
        return body:LayoutChildren()
    end

    function matchWidth:Layout(availableWidth, availableHeight)
        local width, _ = target:Size(availableWidth, availableHeight)
        local _, height = body:Layout(width, availableHeight)
        return width, height
    end

    function matchWidth:Position(...)
        body:Position(...)
    end

    return matchWidth
end

-- A variable-width interface component that positions its content vertically, consuming all available vertical space.
local function VerticalFrame(body, yAnchor)
    local frame = {}

    local height
    local bodyHeight

    function frame:LayoutChildren()
        return body:LayoutChildren()
    end

    function frame:Layout(availableWidth, availableHeight)
        local bodyWidth, _bodyHeight = body:Layout(availableWidth, availableHeight)
        height = availableHeight
        bodyHeight = _bodyHeight
        return bodyWidth, availableHeight
    end
    function frame:Position(x, y)
        body:Position(x, y + (height - bodyHeight) * yAnchor)
    end

    return frame
end

-- An variable-height interface component that positions its content horizontally, consuming all horizontal space. 
local function HorizontalFrame(body, xAnchor)
    local frame = {}

    local width
    local bodyWidth

    function frame:LayoutChildren()
        return body:LayoutChildren()
    end

    function frame:Layout(availableWidth, availableHeight)
        local _bodyWidth, bodyHeight = body:Layout(availableWidth, availableHeight)
        width = availableWidth
        bodyWidth = _bodyWidth
        return availableWidth, bodyHeight
    end
    function frame:Position(x, y)
        body:Position(x + (width - bodyWidth) * xAnchor, y)
    end

    return frame
end

-- Constrains the height of its body to the height of the provided GeometryTarget.
local function MatchHeight(target, body)
    local matchHeight = {}

    function matchHeight:LayoutChildren()
        return body:LayoutChildren()
    end

    function matchHeight:Layout(availableWidth, availableHeight)
        local _, height = target:Size(availableWidth, availableHeight)
        local width, _ = body:Layout(availableWidth, height)
        return width, height
    end

    function matchHeight:Position(...)
        body:Position(...)
    end

    return matchHeight
end

------------------------------------------------------------------------------------------------------------
-- Additional Keyboard Components
------------------------------------------------------------------------------------------------------------

local keypadSpacing = 5
local keySpacing = 1
local baseKeyHeight = 25
local baseKeyWidth = 27

-- Draws a single keyboard key into a drawable interface component
local function UIKey(key, baseKeyWidth, rowHeight, keySpacing)
    local uiKey

    local backgroundColor = MasterFramework:Color(0, 0, 0, 0.66)
    local textColor = MasterFramework:Color(1, 1, 1, 1)

    local keyWidth = MasterFramework:AutoScalingDimension(key.width * baseKeyWidth + (key.width - 1) * keySpacing)
    local keyHeight = MasterFramework:AutoScalingDimension(rowHeight)
    uiKey = MasterFramework:MouseOverChangeResponder(
        MasterFramework:MousePressResponder(
            MasterFramework:StackInPlace({
                MasterFramework:Background(MasterFramework:Rect(keyWidth, keyHeight), { backgroundColor }, MasterFramework:AutoScalingDimension(5)),
                -- { Layout = function() return 10, 10 end, Draw = function() end }
                -- MasterFramework:WrappingText(key.name, textColor, MasterFramework:Font("Poppins-Regular.otf", 12, 0.2, 1.3))
                MasterFramework:Text(key.name, textColor, nil, nil, MasterFramework:Font("Poppins-Regular.otf", 12, 0.2, 1.3))
            }, 0.5, 0.5),
            function()
                if uiKey.selectable then
                    backgroundColor:SetRawValues(1, 0, 0, 0.66)
                    return true
                end
            end,
            function(responder, x, y)
                if MasterFramework.PointIsInRect(x, y, responder:Geometry()) then
                    backgroundColor:SetRawValues(1, 0, 0, 0.66)
                else
                    backgroundColor:SetRawValues(0, 0, 0, 0.66)
                end
            end,
            function(responder, x, y)
                if MasterFramework.PointIsInRect(x, y, responder:Geometry()) then
                    backgroundColor:SetRawValues(0, 0, 0, 0.66)
                    if uiKey._uiKey_action then uiKey:_uiKey_action() end
                end
            end
        ),
        function(isOver)
            if uiKey._uiKey_hoverAction then uiKey:_uiKey_hoverAction(isOver) end
        end
    )
    uiKey.selectable = true

    uiKey._keyCode = key.code

    local wasPressed = false
    function uiKey:SetPressed(isPressed)
        local textBrightness
        if isPressed then
            textBrightness = 0
        else
            textBrightness = 1
        end

        local backgroundBrightness = 1 - textBrightness
        backgroundColor:SetRawValues(backgroundBrightness, backgroundBrightness, backgroundBrightness, 0.66)
        textColor:SetRawValues(textBrightness, textBrightness, textBrightness, 1)

        local shouldUpdate = (wasPressed ~= isPressed)
        wasPressed = isPressed

        return shouldUpdate
    end

    uiKey:SetPressed(false)

    function uiKey:SetBackgroundColor(newColor)
        local r, g, b = newColor:GetRawValues()
        backgroundColor:SetRawValues(r, g, b, 0.66)
    end

    return uiKey
end

-- Converts a keypad layout (columns of rows of keys) into a drawable interface component.
local function KeyPad(keyColumns, keySpacing, baseKeyWidth, baseKeyHeight)
    local keyPad = { keys = {} }

    local scalableKeySpacing = MasterFramework:AutoScalingDimension(keySpacing)

    local uiColumns = map(keyColumns, function(key, column)
        local uiColumn = MasterFramework:VerticalStack(
            map(column, function(key, row)
                local rowHeight = row.height * baseKeyHeight + (row.height - 1) * keySpacing
                local keys = map(row.keys, function(key, value)
                    local uiKey = UIKey(value, baseKeyWidth, rowHeight, keySpacing)
                    return key, uiKey
                end)

                keyPad.keys = joinArrays({ keyPad.keys, keys })

                local uiRow = MasterFramework:HorizontalStack(
                    keys,
                    scalableKeySpacing,
                    0.5
                )
                return key, uiRow
            end),
            scalableKeySpacing,
            0.5
        )

        return key, uiColumn
    end)

    local body = MasterFramework:MarginAroundRect(
        MasterFramework:HorizontalStack(
            uiColumns,
            scalableKeySpacing,
            0.5
        ),
        scalableKeySpacing,
        scalableKeySpacing,
        scalableKeySpacing,
        scalableKeySpacing,
        {},
        MasterFramework:AutoScalingDimension(5),
        false
    )

    function keyPad:HighlightSelectedKeys()
    end
    
    function keyPad:LayoutChildren()
        return body:LayoutChildren()
    end

    function keyPad:Layout(...)
        return body:Layout(...)
    end
    function keyPad:Position(...)
        return body:Position(...)
    end

    return keyPad
end

------------------------------------------------------------------------------------------------------------
-- Keyboard Components
------------------------------------------------------------------------------------------------------------

-- Describes the height and contents of a row of keys on the keyboard
local function KeyRow(height, keys)
    return {
        height = height,
        keys = keys
    }
end

-- Describes the name, code, and width of a key on a keyboard.
local function Key(name, width)
    local code = keyNames[name]
    local key = {
        width = width or 1,
        code = code,
        name = code and keyCodes[code].compressedName or name,
        type = code and keyCodes[code].type or keyCodeTypes.unknown
    }

    return key
end

-- Describes a column of rows on the keyboard
local function KeyColumn(keyRows)
    return keyRows
end

------------------------------------------------------------------------------------------------------------
-- Keycode and Keypad data
------------------------------------------------------------------------------------------------------------

-- End of file. Now we'll declare keycodes and keypads.
-- These are declared as local at the top of the file, and defined here.

keyCodeTypes = {
    unknown = 0,
    modifier = 1,
    operation = 2,
    character = 3
}

local keyCodesFileName = "LuaUI/Widgets/keyCodes/sdl1KeyCodes.lua"
local keyCodesFile = VFS.LoadFile(keyCodesFileName)
local chunk, _error = loadstring(keyCodesFile, keyCodesFileName)
if not chunk or _error then
    error(_error)
end
setfenv(chunk, { keyCodeTypes = keyCodeTypes })
keyCodes = chunk()

keyNames = {}
for code, key in pairs(keyCodes) do
    keyNames[key.name] = code
end

-- Now we declare the stuff built on keycodes

OperationKeys = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("Print Screen"), [2] = Key("Scroll Lock"), [3] = Key("Pause") })
    })
}

FKeys = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("F1"), [2] = Key("F2"), [3] = Key("F3"), [4] = Key("F4"), [5] = Key("F5"), [6] = Key("F6"), [7] = Key("F7"), [8] = Key("F8"), [9] = Key("F9"), [10] = Key("F10"), [11] = Key("F11"), [12] = Key("F12") }),
    })
}

MainKeypad = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("`"), [2] = Key("1"), [3] = Key("2"), [4] = Key("3"), [5] = Key("4"), [6] = Key("5"), [7] = Key("6"), [8] = Key("7"), [9] = Key("8"), [10] = Key("9"), [11] = Key("0"), [12] = Key("-"), [13] = Key("="), [14] = Key("Backspace", 2) }),
        [2] = KeyRow(1, { [1] = Key("Tab", 1.5), [2] = Key("Q"), [3] = Key("W"), [4] = Key("E"), [5] = Key("R"), [6] = Key("T"), [7] = Key("Y"), [8] = Key("U"), [9] = Key("I"), [10] = Key("O"), [11] = Key("P"), [12] = Key("["), [13] = Key("]"), [14] = Key("\\", 1.5) }),
        [3] = KeyRow(1, { [1] = Key("Capslock", 2), [2] = Key("A"), [3] = Key("S"), [4] = Key("D"), [5] = Key("F"), [6] = Key("G"), [7] = Key("H"), [8] = Key("J"), [9] = Key("K"), [10] = Key("L"), [11] = Key(";"), [12] = Key("'"), [13] = Key("Return", 2) }),
        [4] = KeyRow(1, { [1] = Key("Left Shift", 2.5), [2] = Key("Z"), [3] = Key("X"), [4] = Key("C"), [5] = Key("V"), [6] = Key("B"), [7] = Key("N"), [8] = Key("M"), [9] = Key(","), [10] = Key("."), [11] = Key("/"), [12] = Key("Right Shift", 2.5) }),
        [5] = KeyRow(1, { [1] = Key("Left Control", 1.5), [2] = Key(""), [3] = Key("Left Alt", 1.5), [4] = Key("Space", 7), [5] = Key("Right Alt", 1.5), [6] = Key("Menu"), [7] = Key("Right Control", 1.5) })
    })
}


EscapeKey = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("Escape") })
    })
}


NavigationKeys = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("Insert"), [2] = Key("Home"), [3] = Key("Page Up"  ) }),
        [2] = KeyRow(1, { [1] = Key("Delete"), [2] = Key("End" ), [3] = Key("Page Down") })
    })
}


ArrowKeys = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("Up") }),
        [2] = KeyRow(1, { [1] = Key("Left"), [2] = Key("Down"), [3] = Key("Right") })
    })
}

NumericKeypad = {
    [1] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("Num Lock" ), [2] = Key("/ (KP)"), [3] = Key("* (KP)") }),
        [2] = KeyRow(1, { [1] = Key("7 (KP)"   ), [2] = Key("8 (KP)"), [3] = Key("9 (KP)") }),
        [3] = KeyRow(1, { [1] = Key("4 (KP)"   ), [2] = Key("5 (KP)"), [3] = Key("6 (KP)") }),
        [4] = KeyRow(1, { [1] = Key("1 (KP)"   ), [2] = Key("2 (KP)"), [3] = Key("3 (KP)") }),
        [5] = KeyRow(1, { [1] = Key("0 (KP)", 2                     ), [2] = Key(". (KP)") })
    }),
    [2] = KeyColumn({
        [1] = KeyRow(1, { [1] = Key("- (KP)") }),
        [2] = KeyRow(2, { [1] = Key("+ (KP)") }),
        [3] = KeyRow(2, { [1] = Key("Enter (KP)") })
    })
}

function WG.MasterGUIKeyboard()
    mainKeypad = KeyPad(MainKeypad, keySpacing, baseKeyWidth, baseKeyHeight)
    escapeKeypad = KeyPad(EscapeKey, keySpacing, baseKeyWidth, baseKeyHeight)
    arrowKeypad = KeyPad(ArrowKeys, keySpacing, baseKeyWidth, baseKeyHeight)
    navigationKeypad = KeyPad(NavigationKeys, keySpacing, baseKeyWidth, baseKeyHeight)
    numericKeypad = KeyPad(NumericKeypad, keySpacing, baseKeyWidth, baseKeyHeight)
    fKeypad = KeyPad(FKeys, keySpacing, baseKeyWidth, baseKeyHeight)
    operationKeypad = KeyPad(OperationKeys, keySpacing, baseKeyWidth, baseKeyHeight)
    
    local mainKeypadGeometryTarget = MasterFramework:GeometryTarget(mainKeypad)

    local keyboard = MasterFramework:HorizontalStack({
            MasterFramework:VerticalStack({
                    MatchWidth(
                        mainKeypadGeometryTarget,
                        MasterFramework:StackInPlace({
                            HorizontalFrame(escapeKeypad, 0),
                            HorizontalFrame(fKeypad, 1)
                        }, 0, 0)
                    ),
                    mainKeypadGeometryTarget
                },
                MasterFramework:AutoScalingDimension(keypadSpacing),
                0
            ),
            MasterFramework:VerticalStack({
                    operationKeypad,
                    MatchHeight(
                        mainKeypadGeometryTarget,
                        MasterFramework:StackInPlace({
                            VerticalFrame(navigationKeypad, 1),
                            VerticalFrame(arrowKeypad, 0)
                        }, 0, 0)
                    )
                },
                MasterFramework:AutoScalingDimension(keypadSpacing),
                0
            ),
            numericKeypad
        },
        MasterFramework:AutoScalingDimension(keypadSpacing),
        0
    )

    keyboard.mainKeypad = mainKeypad
    keyboard.escapeKeypad = escapeKeypad
    keyboard.arrowKeypad = arrowKeypad
    keyboard.navigationKeypad = navigationKeypad
    keyboard.numericKeypad = numericKeypad
    keyboard.fKeypad = fKeypad
    keyboard.operationKeypad = operationKeypad
    
    keyboard.uiKeys = {}

    for _, value in ipairs(joinArrays(imap({ mainKeypad, escapeKeypad, arrowKeypad, navigationKeypad, numericKeypad, fKeypad, operationKeypad }, function(_, value) return value.keys end))) do
        if value._keyCode then
            keyboard.uiKeys[value._keyCode] = value
        end
    end

    return keyboard
end