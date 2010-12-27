local print = print
local pairs = pairs
local ipairs = ipairs
local window = window
local luakit = luakit
local lousy = require "lousy"

local new_mode, add_binds, add_cmds, menu_binds = new_mode, add_binds, add_cmds, menu_binds

module("auth")

-- the authentication prompt
local dat = {
    username = nil,
    password = nil,
    uri = nil,
}
new_mode("authenticate", {
    enter = function (w)
        dat.username = nil
        dat.password = nil
        w:set_prompt("Login for " .. dat.uri .. ":")
        w:set_input("")
    end,

    activate = function (w)
        if dat.username == nil then
            dat.username = w.ibar.input.text
            w:set_prompt("Password for " .. dat.uri .. ":")
            w:set_input("")
        else
            dat.password = w.ibar.input.text
            w:set_mode()
        end
    end,

    leave = function (w)
        if dat.username ~= nil and dat.password ~= nil then
            w.win:authenticate(dat.username, dat.password)
        end
    end,
})

-- register authentication function
luakit.add_signal("authenticate", function (uri)
    for _, w in pairs(window.bywidget) do
        for _, v in ipairs(w.tabs:get_children()) do
            if v.uri == uri then
                dat.uri = uri
                w:set_mode("authenticate")
            end
        end
    end
end)

