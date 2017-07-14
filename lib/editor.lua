--- Text editor launching functionality.
--
-- This module is primarily for use by other Lua modules that wish to
-- allow the user to edit a particular text file. This module does not
-- have any user-facing modifications or features.
--
-- @module editor

local globals = require("globals")
local capi = { luakit = luakit }

local _M = {}

--- Edit a file in a terminal editor in a new window.
--
-- * Can't yet handle files with special characters in their name.
-- * Can't yet use a graphical text editor (terminal only).
-- * Can't determine when text editor is closed.
--
-- @tparam string file The path of the file to edit.
-- @tparam number line The line number at which to begin editing.
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
