
local keymap = {}

-- A table that contains mappings for key names.
-- If a keyname is in this table then convertion by group will not be applied
keymap.map = {
        ISO_Left_Tab = "Tab",
    }

-- true if a keyval of pressed key should be converted to the keyval which corresponds to the default keyboard layout
keymap.convert_groups = {
    -- for example: setxkbmap "us,ru,dvorak" "grp:caps_toggle"
    [0] = true,     -- ru: conversion is useful for non-latin layout
    [2] = false,    -- dvorak: such conversion is unconfortable for dvorak
}

return keymap

-- vim: et:sw=4:ts=8:sts=4:tw=80
