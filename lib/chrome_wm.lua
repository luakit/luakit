-- Add custom luakit:// scheme rendering functions.
-- @submodule chrome
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local ui = ipc_channel("chrome_wm")

local _M = {}

local pending = {}
local next_id = 0

ui:add_signal("function-return", function (_, _, id, ok, ret)
    local callbacks = assert(pending[id])
    pending[id] = nil
    (callbacks[ok and "resolve" or "reject"])(ret)
end)

ui:add_signal("register-function", function (_, _, page_name, func_name)
    local pattern = "^luakit://" .. page_name .. "/?(.*)"
    luakit.register_function(pattern, func_name, function (page, resolve, reject, ...)
        pending[next_id] = { resolve = resolve, reject = reject }
        ui:emit_signal("function-call", page.id, page_name, func_name, next_id, {...})
        next_id = next_id + 1
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
