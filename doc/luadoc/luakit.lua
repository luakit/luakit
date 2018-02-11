--- Luakit core API
--
-- DOCMACRO(alert:Some functions and fields are not available from web processes.)
--
-- This library provides a set of infrastructure and utility functions for
-- controlling luakit, accessing and modifying current settings, running
-- background programs, and more.
--
-- @author Aidan Holm <aidanholm@gmail.com>
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @author Paweł Zuzelski <pawelz@pld-linux.org>
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>
-- @copyright Paweł Zuzelski <pawelz@pld-linux.org>
-- @module luakit

--- The path to the luakit configuration directory.
-- @property config_dir
-- @type string
-- @readonly

--- The path to the luakit data directory.
-- @property data_dir
-- @type string
-- @readonly

--- The path to the luakit cache directory.
-- @property cache_dir
-- @type string
-- @readonly

--- Whether luakit is using verbose logging. `true` if logging in `verbose` or
--`debug` mode.
-- @property verbose
-- @type boolean
-- @readonly

--- The luakit installation path.
-- @deprecated use @ref{install_paths|install_paths.install_dir} instead.
-- @property install_path
-- @type string
-- @readonly

--- The paths to where luakit's files are installed.
-- @property install_paths
-- @type table
-- @readonly

--- The luakit version.
-- @property version
-- @type string
-- @readonly

--- The WebKitGTK version that luakit was built with.
-- @property webkit_version
-- @type string
-- @readonly

--- An array of all active window widgets.
-- @property windows
-- @type {widget}
-- @readonly

--- Quit luakit immediately, without asking modules for confirmation.
-- @function quit

--- Callback type for @ref{spawn}.
-- @callback process_exit_cb
-- @tparam string reason The reason for process termination. Can be one of `"exit"`, indicating normal termination;
-- `"signal"`, indicating the process was killed with a signal; and `"unknown"`.
-- @tparam integer status The exit status code of the process. Its meaning is system-dependent.

--- Spawn a process asynchronously.
-- @tparam string cmd The command to execute. It is parsed with a simple shell-like parser.
-- @tparam[opt] function callback A callback function to execute when the spawned
-- process is terminated, of type @ref{process_exit_cb}.
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
-- @function uri_decode
-- @tparam string str The string to decode.
-- @treturn string The unescaped/decoded string, or `nil` on error.
-- @treturn string Error message.

--- Idle callback function type.
-- Return `true` to keep the callback running on idle.
-- Returning `false` or `nil` will cause the callback to be
-- automatically removed from the set of registered idle functions.
-- @treturn boolean Whether the callback should be kept running on idle.
-- @callback idle_cb

--- Add a function to be called regularly when Luakit is idle. If the function
-- returns `false`, or if an error is encountered during execution, the function
-- is automatically removed from the set of registered idle functions, and will
-- not be called again.
--
-- The provided callback function is not called with any arguments; to pass
-- context to the callback function, use a closure.
--
-- @function idle_add
-- @tparam function cb The function to call when Luakit is idle, of type @ref{idle_cb}.

--- Remove a function previously registered with @ref{idle_add}.
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
-- # Example
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

--- The current contents of the different X selections.
-- The key used to access this table must be the name of the X clipboard
-- to use (one of `"primary"`, `"secondary"` or `"clipboard"`).
-- # Primary
-- When the user selects some text with the mouse, the primary selection
-- is filled automatically with the contents of that text selection.
-- # Secondary
-- The secondary selection is not used as much as the primary and clipboard
-- selections, but is included here for completeness.
-- # Clipboard
-- The clipboard selection is filled with the contents of the primary selection
-- when the user explicitly requests a copy operation.
-- @type {[string]=string}
-- @readwrite
-- @property selection

--- Convert a key or key name to uppercase.
-- @tparam string key The key or key name to convert.
-- @treturn string The converted key. This will be the same as `key` if the key
-- is already uppercase or if case conversion does not apply to the key.
-- @function wch_upper

--- Convert a key or key name to lowercase.
-- @tparam string key The key or key name to convert.
-- @treturn string The converted key. This will be the same as `key` if the key
-- is already lowercase or if case conversion does not apply to the key.
-- @function wch_lower

--- The set of paths used by luakit to search for resource files.
-- This property is similar to `package.path`; it is a semicolon-separated list
-- of paths, and paths appearing earlier in the list will be searched first when
-- looking for resource files.
--
-- By default, it includes the current directory and the luakit installation
-- directory.
-- @type string
-- @readwrite
-- @property resource_path

-- vim: et:sw=4:ts=8:sts=4:tw=80
