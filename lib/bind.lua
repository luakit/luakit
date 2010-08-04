local table = table
local setmetatable = setmetatable
local print = print
local pairs = pairs
local ipairs = ipairs
local assert = assert
local type = type
local util = require("util")
local unpack = unpack

module("bind")

-- Modifiers to ignore
ignore_modifiers = { "Mod2", "Lock" }

-- Return cloned, sorted & filtered modifier mask table.
function filter_mods(mods, remove_shift)
    -- Clone & sort new modifiers table
    local mods = util.table.clone(mods)
    table.sort(mods)

    -- Filter out ignored modifiers
    mods = util.table.difference(mods, ignore_modifiers)

    if remove_shift then
        mods = util.table.difference(mods, { "Shift" })
    end

    return mods
end

-- Create new key binding
function key(mods, key, func)
    local mods = filter_mods(mods, #key == 1)
    return { mods = mods, key = key, func = func }
end

-- Check if a bind exists with the given key & modifier mask then call the
-- binds function with `object` as the first argument.
function hit(binds, mods, key, ...)
    -- Filter modifers table
    local mods = filter_mods(mods, #key == 1)
    for _, k in ipairs(binds) do
        if k.key == key and util.table.isclone(k.mods, mods) then
            k.func(unpack(arg))
            return true
        end
    end
    return false
end
