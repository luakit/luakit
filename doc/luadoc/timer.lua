--- Timer support for Luakit.
--
-- # Example usage:
--
--     local t = timer{ interval = 500 }
--
--     t:add_signal("timeout", function ()
--         print("500msec later!")
--     end)
--
--     t:start()
--
-- @class timer
-- @author Mason Larobina
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

--- @function __call
-- Create a new timer instance.
-- @tparam[opt] table properties Any initial timer properties to set.
-- @default `{}`

--- @method start
-- Start a timer.
--
-- The timer must already have an interval set.
-- The timer should not already be running.

--- @method stop
-- Stop a timer.
--
-- The timer should already be running.

--- @property interval
-- The interval of the timer, in milliseconds.
-- @type integer
-- @readwrite

--- @property started
-- Whether the timer is running.
-- @type boolean
-- @readonly
-- @default `false`

--- @signal timeout
-- This signal is emitted when the time on the timer has expired.
-- @tparam timer timer The timer that has expired.

-- vim: et:sw=4:ts=8:sts=4:tw=80
