--------------------------------------------------------
-- Save web history                                   --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

local os = os
local io = io
local string = string

local webview = webview
local capi = { luakit = luakit }

module("history")

-- Location to save web history
file = capi.luakit.data_dir .. "/history"

-- Save web history
webview.init_funcs.save_hist = function (view)
    view:add_signal("load-status", function (v, status)
        if status == "first-visual" then
            local fh = io.open(file, "a")
            fh:write(string.format("%d %s\n", os.time(), v.uri))
            fh:close()
        end
    end)
end

