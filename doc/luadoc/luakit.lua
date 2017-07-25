--- Luakit core API
--
-- DOCMACRO(builtin)
-- DOCMACRO(alert:Some functions and fields are not available from web processes.)
--
-- @author Aidan Holm <aidanholm@gmail.com>
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @author Paweł Zuzelski <pawelz@pld-linux.org>
-- @copyright 2016 Aidan Holm
-- @copyright 2010 Mason Larobina, Paweł Zuzelski
-- @module luakit

--- The configuration directory path (default: `$XDG_CONFIG_HOME`).
-- @field config_dir
-- @type string
-- @readonly

--- The data directory path (default: `$XDG_DATA_HOME`).
-- @field data_dir
-- @type string
-- @readonly

--- The cache directory path (default: `$XDG_CACHE_HOME`).
-- @field cache_dir
-- @type string
-- @readonly

--- Whether luakit is using verbose logging. `true` if logging in `verbose` or
--`debug` mode.
-- @field verbose
-- @type boolean
-- @readonly

--- The luakit installation path.
-- @field install_path
-- @type string
-- @readonly

--- The luakit version.
-- @field version
-- @type string
-- @readonly

--- An array of all active window widgets.
-- @field windows
-- @type {widget}
-- @readonly

--- Quit luakit immediately, without asking modules for confirmation.
-- @function quit

--- Get the contents of the X selection.
-- @tparam string clipboard The name of the X clipboard to use (one of `"primary"`, `"secondary"` or `"clipboard"`).
-- @treturn string The contents of the named selection.
-- @function get_selection

--- Set the contents of the X selection.
-- @tparam string text The UTF-8 string to be copied to the named selection.
-- @tparam string clipboard The name of the X clipboard to use (one of `"primary"`, `"secondary"` or `"clipboard"`).
-- @function set_selection

--- Spawn a process asynchronously.
-- @tparam string cmd The command to execute. It is parsed with a simple shell-like parser.
-- @function spawn

--- Spawn a process synchronously.
-- DOCMACRO(alert:This will block the luakit UI until the process exits.)
-- @tparam string cmd The command to execute. It is parsed with a simple shell-like parser.
-- @treturn number The exit status of the command.
-- @treturn string A string containig data printed on `stdout`.
-- @treturn string A string containig data printed on `stderr`.
-- @function spawn_sync

--- Get the time since Luakit startup.
-- @function time
-- @treturn number The number of seconds Luakit has been running.

--- Escape a string for use in a URI.
-- @function uri_encode
-- @tparam string str The string to encode.
-- @treturn string The escaped/encoded string.

--- Unescape an escaped string used in a URI.
--
-- Returns the unescaped string, or `nil` if the string contains illegal
-- characters.
--
-- @function uri_encode
-- @tparam string str The string to decode.
-- @treturn string The unescaped/decoded string, or `nil` on error.
-- @treturn string Error message.

--- Add a function to be called regularly when Luakit is idle. If the function
-- returns `false`, or if an error is encountered during execution, the function
-- is automatically removed from the set of registered idle functions, and will
-- not be called again.
--
-- The provided callback function is not called with any arguments; to pass
-- context to the callback function, use a closure.
--
-- @function idle_add
-- @tparam function cb The function to call when Luakit is idle.

--- Remove a function previously registered with `idle_add`.
--
-- @function idle_remove
-- @tparam function cb The function to removed from the set of idle callbacks.
-- @treturn boolean `true` if the callback was present (and removed); `false` if the
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
-- @function register_scheme
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
-- @tparam page page The new page object.

--- Whether spell checking is enabled.
-- @property enable_spell_checking
-- @readwrite
-- @type boolean
-- @default `false`

--- The set of languages to use for spell checking, if spell checking is
-- enabled.
--
-- Each item in the table is a code of the form `lang_COUNTRY`,
-- where `lang` is an ISO-639 language code, in lowercase, and `COUNTRY`
-- is an ISO-3166 country code, in uppercase.
--
-- When setting a new value for this property, any unrecognized codes are
-- discarded and a warning is logged, but no error is generated.
--
-- This property has a default value based on the user's locale. Setting this
-- value to `{}` will reset it to the default value.
--
-- @property spell_checking_languages
-- @readwrite
-- @type {string}

-- vim: et:sw=4:ts=8:sts=4:tw=80
