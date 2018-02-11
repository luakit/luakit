--- Message logging support for Lua.
--
-- This built-in library offers support for logging messages from Lua code. Five
-- verbosity levels are available. By default, _verbose_ and _debug_ messages
-- are not shown, but this can be changed when launching Luakit.
--
-- All parameters are converted to strings. A newline is automatically appended.
--
--     webview.add_signal("init", function (view)
--         msg.debug("Opening a new web view <%d>", view.id)
--     end)
--
-- @module msg
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

--- Log a fatal error message, and abort the program.
-- @function fatal
-- @tparam string format Format string.
-- @param ... Additional arguments referenced from the format string.

--- Log a warning message.
-- @function warn
-- @tparam string format Format string.
-- @param ... Additional arguments referenced from the format string.

--- Log an informational message.
-- @function info
-- @tparam string format Format string.
-- @param ... Additional arguments referenced from the format string.

--- Log a verbose message.
-- @function verbose
-- @tparam string format Format string.
-- @param ... Additional arguments referenced from the format string.

--- Log a debug message.
-- @function debug
-- @tparam string format Format string.
-- @param ... Additional arguments referenced from the format string.

--- @signal log
-- Emitted when a message is logged. This signal is not emitted for messages
-- below the current log level.
-- @tparam string level The level at which the message was logged.
-- @tparam string group The origin of the message.
-- @tparam string msg The message itself. May contain ANSI color escape codes.

-- vim: et:sw=4:ts=8:sts=4:tw=80
