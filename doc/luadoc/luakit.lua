--- Luakit core API
--
-- DOCMACRO(builtin)
-- DOCMACRO(available:both)
-- DOCMACRO(alert:Some functions and fields are not available from web processes.)
--
-- @author Aidan Holm <aidanholm@gmail.com>
-- @author Mason Larobina &lt;mason.larobina&lt;AT&gt;gmail.com&gt;
-- @author Paweł Zuzelski &lt;pawelz&lt;AT&gt;pld-linux.org&gt;
-- @copyright 2016 Aidan Holm
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

--- Get the time since Luakit startup.
--
-- @function luakit.time
-- @treturn number The number of seconds Luakit has been running.

--- Escape a string for use in a URI.
--
-- @function luakit.uri_encode
-- @tparam string str The string to encode.
-- @treturn string The escaped/encoded string.

--- Unescape an escaped string used in a URI.
--
-- Returns the unescaped string, or nil if the string contains illegal
-- characters.
--
-- @function luakit.uri_encode
-- @tparam string str The string to decode.
-- @treturn string The unescaped/decoded string, or `nil` on error.
-- @treturn string Error message.

--- Add a function to be called regularly when Luakit is idle. If the function
-- returns false, or if an error is encountered during execution, the function
-- is automatically removed from the set of registered idle functions, and will
-- not be called again.
--
-- The provided callback function is not called with any arguments; to pass
-- context to the callback function, use a closure.
--
-- @function luakit.idle_add
-- @tparam function cb The function to call when Luakit is idle.

--- Remove a function previously registered with `luakit.idle_add`.
--
-- @function luakit.idle_remove
-- @tparam function cb The function to removed from the set of idle callbacks.
-- @treturn boolean True if the callback was present (and removed); false if the
-- callback was not found.

--- Register a custom URI scheme.
--
-- Registering a scheme causes network requests to that scheme to be redirected
-- to Lua code via the signal handling interface. A signal based on the scheme
-- name will be emitted on a webview widget when it attempts to load a URI on
-- the registered scheme. To return content to display, as well as an optional
-- mime-type, connect to the signal and return a string with the content to
-- display.
--
-- This interface is used to register the `luakit://` scheme, but is not limited
-- to this prefix alone.
--
-- #### Example
--
-- Registering a scheme `foo` will cause URIs beginning with `foo://` to
-- be redirected to Lua code. A signal `scheme-request::foo` will be emitted on
-- a webview in response to a `foo://` load attempt, and should be handled to
-- provide contentt.
--
-- @function luakit.register_scheme
-- @tparam string scheme The network scheme to register.

--- @signal page-created
--
-- DOCMACRO(alert:This signal is only emitted on the web process of the
-- newly-created page.)
--
-- Emitted after the creation of a [`page`](../classes/page.html) object; i.e. after
-- a new webview widget has been created in the UI process.
--
-- @usage
--
--     luakit.add_signal("page-created", function (page)
--         -- Add more signals to page
--     end)
--
-- @tparam page page

-- vim: et:sw=4:ts=8:sts=4:tw=80
