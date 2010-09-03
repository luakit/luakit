---------------------------------------------------------
-- Input bar notification for luakit                   --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

-- Shows a notification until the next keypress of the user.
window.methods.notify = function (w, text)
    local s = w.sbar.l.uri
    s.text = text
    s:show()
    w.sbar.notification = true
end

-- Wrapper around luakit.set_selection that shows a notification
window.methods.set_selection = function (w, text)
    luakit.set_selection(text)
    w:notify("yanked " .. text)
end


