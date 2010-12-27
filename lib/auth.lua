local print = print
local lousy = require "lousy"

local new_mode, add_binds, add_cmds, menu_binds = new_mode, add_binds, add_cmds, menu_binds

module("auth")

-- the authentication prompt
local username, password
new_mode("authenticate", {
    enter = function (w)
        username = nil
        password = nil
        w:set_prompt("Login:")
        w:set_input("")
    end,

    activate = function (w)
        if username == nil then
            username = w.ibar.input.text
            w:set_prompt("Password:")
            w:set_input("")
        else
            password = w.ibar.input.text
            w:set_mode()
        end
    end,

    leave = function (w)
        if username == nil or password == nil then
            w:authenticate()
        else
            w:authenticate(username, password)
        end
    end,
})

-- register authentication function
luakit.add_signal("authenticate", function (uri)
    -- TODO: find window
    w:set_mode("authenticate")
    return true
end)

