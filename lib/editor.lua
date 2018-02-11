--- Text editor launching functionality.
--
-- This module is primarily for use by other Lua modules that wish to
-- allow the user to edit a particular text file. The default is to guess at the
-- shell command to open a text editor from environment variables. To override
-- the guess, replace `editor.cmd_string`. This can be done manually, as follows:
--
--     local editor = require "editor"
--     editor.editor_cmd = "urxvt -e nvim {file} +{line}"
--
-- Before running the command, `{file}` will be replaced by the name of the file
-- to be edited, and `{line}` will be replaced by the number of the line at
-- which to begin editing. This module also supplies several builtin command
-- strings, which can be used like this:
--
--     local editor = require "editor"
--     editor.editor_cmd = editor.builtin.urxvt
--
-- @module editor
-- @copyright 2017 Graham Leach-Krouse
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local _M = {}

-- substitute in common values from the environment.
local env_sub = function (s)
    local subs = {
        term =  os.getenv("TERMINAL") or "xterm",
        editor = os.getenv("EDITOR") or "vim"
    }
    return string.gsub(s,"{(%w+)}", subs)
end

--- Built in substitution strings. Includes
--
-- * `autodetect` (attempts to extract a terminal and editor from environment
-- variables, and otherwise falls back to xterm and vim)
-- * `xterm`
-- * `urxvt`
-- * `xdg_open`
--
-- @type table
-- @readonly
_M.builtin = {
    autodetect = env_sub("{term} -e '{editor} {file} +{line}'"),
    xterm = env_sub("xterm -e {editor} {file} +{line}"),
    urxvt = env_sub("urxvt -e {editor} {file} +{line}"),
    xdg_open = env_sub("xdg-open {file}"),
}

--- The shell command used to open the editor. The default setting is to
-- use `editor.builtin.xdg_open`.
--
-- @type string
-- @readwrite
_M.editor_cmd = _M.builtin.xdg_open

--- Edit a file in a terminal editor in a new window.
--
-- * Can't yet handle files with special characters in their name.
--
-- @tparam string file The path of the file to edit.
-- @tparam[opt] number line The line number at which to begin editing.
-- @tparam[opt] function callback A callback that fires when the process spawned
-- by the editor command exits, of type @ref{process_exit_cb}.
_M.edit = function (file, line, callback)
    local subs = {
        file = file,
        line = line or 1,
    }
    local cmd = string.gsub(_M.editor_cmd, "{(%w+)}", subs)
    luakit.spawn(cmd, callback)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
