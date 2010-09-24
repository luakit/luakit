------------------------------------------------------------------
-- Go one step upward in the uri path structure.                --
-- (C) 2009 Aldrik Dunbar  (n30n)                               --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

local go_up = [=[
(function() {
    try { // Go up one level
        location = location.href.match(/(\w+:\/\/.+?\/)([\w\?\=\+\%\&\-\.]+\/?)$/)[1];
    }
    catch(e) {
        try { // Removing sub-domain
            var s = document.domain.match(/^(?!www\.)\w+\.(.+?)\.([a-z]{2,4})(?:\.([a-z]{2}))?$/);
            var l = s.length;
            location = location.protocol + "//" + s.slice(1, s[l] ? l : l-1).join(".");
        }
        catch(e) {}
    }
})();
]=]

local go_upmost = [=[
(function() {
    location = location.protocol + "//" + document.domain;
})();
]=]

-- Add `gu` & `gU` binds to the normal mode.
for _, b in ipairs({
    lousy.bind.buf("^gu$", function (w) w:eval_js(go_up)     end),
    lousy.bind.buf("^gU$", function (w) w:eval_js(go_upmost) end),
}) do table.insert(binds.mode_binds.normal, b) end

-- vim: et:sw=4:ts=8:sts=4:tw=80
