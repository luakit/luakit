--- Text editor launching functionality.
--
-- @module editor

local globals = require("globals")
local capi = { luakit = luakit }

local _M = {}

-- Can't yet handle files with special characters in their name
_M.edit = function (file, line)
    local subs = {
        term = globals.term or os.getenv("TERMINAL") or "xterm",
        editor = globals.editor or os.getenv("EDITOR") or "vim",
        file = file,
        line = line and " +" .. tostring(line) or "",
    }
    local cmd_tmpl = "{term} -e '{editor} {file}{line}'"
    local cmd = string.gsub(cmd_tmpl, "{(%w+)}", subs)
    capi.luakit.spawn(cmd)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
