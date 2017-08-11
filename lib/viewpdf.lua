--- Automatic PDF viewing.
--
-- This module automatically downloads PDF files to the luakit cache directory,
-- and opens them with `xdg-open`.
--
-- @module viewpdf
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local downloads = require("downloads")

local _M = {}

downloads.add_signal("download-location", function(_, filename, mime)
    if mime == "application/pdf" then
        local dir = luakit.cache_dir .. "/viewpdf/"

        local mode = lfs.attributes(dir, "mode")
        if mode == nil then
            assert(lfs.mkdir(dir))
        elseif mode ~= "directory" then
            error("Cannot create directory " .. dir)
        end

        return dir .. filename
    end
end)

downloads.add_signal("download::status", function(dl)
    if dl.mime_type == "application/pdf" and dl.status == "finished" then
        downloads.do_open(dl)
    end
end)

downloads.add_signal("open-file", function (file, mime_type)
    if mime_type == "application/pdf" then
        luakit.spawn(string.format("xdg-open %q", file))
        return true
    end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
