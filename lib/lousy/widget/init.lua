--- lousy.widget library.
--
-- @module lousy.widget
-- @author Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local wrap = function (modname)
    return function () return require(modname) end
end

local wrapped = {
    buf      = wrap("lousy.widget.buf"),
    hist     = wrap("lousy.widget.hist"),
    menu     = wrap("lousy.widget.menu"),
    progress = wrap("lousy.widget.progress"),
    scroll   = wrap("lousy.widget.scroll"),
    ssl      = wrap("lousy.widget.ssl"),
    tabi     = wrap("lousy.widget.tabi"),
    tablist  = wrap("lousy.widget.tablist"),
    tab      = wrap("lousy.widget.tab"),
    uri      = wrap("lousy.widget.uri"),
    zoom     = wrap("lousy.widget.zoom"),
}

local unwrap = function (t, k)
    if wrapped[k] then
        t[k] = (wrapped[k])()
        wrapped[k] = nil
        return t[k]
    end
end

return setmetatable({}, { __index = unwrap })

-- vim: et:sw=4:ts=8:sts=4:tw=80
