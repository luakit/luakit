----------------------------------------------------------------
-- Follow "next" or "prev" links on a page                    --
-- © 2009 Aldrik Dunbar  (n30n)                               --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
----------------------------------------------------------------

local go_next_prev_wm = web_module("go_next_prev_webmodule")

-- Add `[[` & `]]` bindings to the normal mode.
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^%]%]$", function (w) go_next_prev_wm:emit_signal("go", w.view.id, "next") end),
    buf("^%[%[$", function (w) go_next_prev_wm:emit_signal("go", w.view.id, "prev") end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
