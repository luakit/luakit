--- Select a page element with a visual interface.
--
-- This module allows you to change the style of hints used to hint elements for
-- selection in `follow` mode, as well as other modes that use the visual hint
-- overlay.
--
-- @module select
-- @copyright 2017 Aidan Holm

local _M = {}

local wrapped = { label_maker = nil }

--- @property label_maker
-- Function that describes how to generate labels for hints. In order to modify
-- the hint label style, set this field to a function that takes one parameter,
-- a table of chainable hint label style functions, and returns a chained set of
-- these functions.
--
-- # Example usage:
--
--     local select = require "select"
--     select.label_maker = function (s)
--         return s.sort(s.reverse(s.charset("asdfqwerzxcv")))
--     end
--
-- @readwrite
-- @default nil
-- @type function

local wm = require_web_module("select_wm")

luakit.add_signal("web-extension-created", function (view)
    if wrapped.label_maker then
        wm:emit_signal(view, "set_label_maker", wrapped.label_maker)
    end
end)

local mt = {
    __index = wrapped,
    __newindex = function (_, k, v)
        assert(type(v) == "function", "property 'label_maker' must be a function")
        if k == "label_maker" then
            wrapped.label_maker = v
            wm:emit_signal("set_label_maker", v)
        end
    end,
}

return setmetatable(_M, mt)

-- vim: et:sw=4:ts=8:sts=4:tw=80
