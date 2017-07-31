--- Follow "next" or "prev" links on a page.
--
-- Many web pages make use of pagination. This module does away with the need to
-- hunt for the next- and previous-page buttons by automatically detecting them
-- and clicking them for you on demand.
--
-- @module go_next_prev
-- @copyright 2009 Aldrik Dunbar  (n30n)
-- @copyright 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>

local modes = require("modes")
local add_binds = modes.add_binds

local _M = {}

local go_next = [=[
(function() {
    function click(e) {
        if (e.href)
            document.location = e.href;
        else {
            var ev = document.createEvent("MouseEvent");
            ev.initMouseEvent("click", true, true, window,
                0, 0, 0, 0, 0, false, false, false, false, 0, null);
            e.dispatchEvent(ev);
        }
    }

    var e = document.querySelector("[rel='next']");
    if (e) // Wow a developer that knows what he's doing!
        click(e);
    else { // Search from the bottom of the page up for a next link.
        var els = document.getElementsByTagName("a");
        var res = "\\bnext\\b,^>$,^(>>|»)$,^(>|»),(>|»)$,\\bmore\\b"
        for (let r of res.split(",").map(r => new RegExp(r, "i"))) {
            var i = els.length;
            while ((e = els[--i])) {
                if (e.text.search(r) > -1) {
                    click(e);
                    return;
                }
            }
        }
    }
})();
]=]

local go_prev = [=[
(function() {
    function click(e) {
        if (e.href)
            document.location = e.href;
        else {
            var ev = document.createEvent("MouseEvent");
            ev.initMouseEvent("click", true, true, window,
                0, 0, 0, 0, 0, false, false, false, false, 0, null);
            e.dispatchEvent(ev);
        }
    }

    var e = document.querySelector("[rel='prev']");
    if (e)
        click(e);
    else {
        var els = document.getElementsByTagName("a");
        var res = "\\b(prev|previous)\\b,^<$,^(<<|«)$,^(<|«),(<|«)$"
        for (let r of res.split(",").map(r => new RegExp(r, "i"))) {
            var i = els.length;
            while ((e = els[--i])) {
                if (e.text.search(r) > -1) {
                    click(e);
                    return;
                }
            }
        }
    }
})();
]=]

-- Add `[[` & `]]` bindings to the normal mode.
add_binds("normal", {
    { "%]%]", "Open the next page in the current tab.",
        function (w) w.view:eval_js(go_next, { no_return = true }) end },
    { "%[%[", "Open the previous page in the current tab.",
        function (w) w.view:eval_js(go_prev, { no_return = true }) end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
