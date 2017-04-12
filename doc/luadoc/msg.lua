--- Message logging support for Lua.
--
-- This built-in library offers support for logging messages from Lua code. Five
-- verbosity levels are available. By default, _verbose_ and _debug_ messages
-- are not shown, but this can be changed when launching Luakit.
--
-- All parameters are converted to strings. A newline is automatically appended.
--
-- _This library is available from both UI and web process Lua states._
--
--     webview.add_signal("init", function (view)
--         msg.debug("Opening a new web view <%d>", view.id)
--     end)
--
-- @module msg
-- @copyright 2016 Aidan Holm

--- Log a fatal error message, and abort the program.
-- @function fatal
-- @tparam string format Format string
-- @param ... Additional arguments referenced from the format string.

--- Log a warning message.
-- @function warn
-- @tparam string format Format string
-- @param ... Additional arguments referenced from the format string.

--- Log an informational message.
-- @function info
-- @tparam string format Format string
-- @param ... Additional arguments referenced from the format string.

--- Log a verbose message.
-- @function verbose
-- @tparam string format Format string
-- @param ... Additional arguments referenced from the format string.

--- Log a debug message.
-- @function debug
-- @tparam string format Format string
-- @param ... Additional arguments referenced from the format string.

-- vim: et:sw=4:ts=8:sts=4:tw=80
