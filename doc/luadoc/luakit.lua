---
-- Luakit core API
--
-- _This library is available from both UI and web process Lua states._
--
-- _Some functions and fields are not available on the web process._
--
-- @author Mason Larobina &lt;mason.larobina&lt;AT&gt;gmail.com&gt;
-- @author Paweł Zuzelski &lt;pawelz&lt;AT&gt;pld-linux.org&gt;
-- @copyright 2010 Mason Larobina, Paweł Zuzelski
-- @module luakit

--- config directory path (default: `$XDG_CONFIG_HOME`)
-- @field config_dir
-- @type string
-- @readonly

--- data directory path (default: `$XDG_DATA_HOME`)
-- @field data_dir
-- @type string
-- @readonly

--- cache directory path (default: `$XDG_CACHE_HOME`)
-- @field cache_dir
-- @type string
-- @readonly

--- verbosity (boolean value)
-- @field verbose
-- @type boolean
-- @readonly

--- luakit installation path (read only property)
-- @field install_path
-- @type string
-- @readonly

--- luakit version (read only property)
-- @field version
-- @type string
-- @readonly

--- All active window widgets
-- @field windows
-- @type {widget}
-- @readonly

--- Quit luakit
-- @function quit

--- Get selection
-- @param clipboard X clipboard name ('primary', 'secondary' or 'clipboard')
-- @return A string with the selection (clipboard) content.
-- @function get_selection

--- Set selection
-- @param text UTF-8 string to be copied to clipboard
-- @param clipboard X clipboard name ('primary', 'secondary' or 'clipboard')
-- @function set_selection

--- Spawn process asynchronously
-- @param cmd Command to execute. It is parsed with simple shell-like parser.
-- @function spawn

--- Spawn process synchronously
-- @param cmd Command to execute. It is parsed with simple shell-like parser.
-- @return An exit status of the command.
-- @return A string containig data printed on stdout.
-- @return A string containig data printed on stderr.
-- @function spawn_sync

-- vim: et:sw=4:ts=8:sts=4:tw=80
