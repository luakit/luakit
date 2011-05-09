-------------------------------------------------------
-- Timers for luakit                                 --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

-- Grab environment from C API
local capi = {
    timer = timer,
}

--- Executes a timer once.
-- @param interval The timeout after which to execute <code>fun</code> in
--      milliseconds.
-- @param fun The function to execute after <code>interval</code>
timer.once = function (interval, fun)
    local t = timer{interval=interval}
    t:add_signal("timeout", function (t)
        t:stop()
        fun()
    end)
    t:start()
end

