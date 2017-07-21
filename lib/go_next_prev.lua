--- Follow "next" or "prev" links on a page.
--
-- Many web pages make use of pagination. This module does away with the need to
-- hunt for the next- and previous-page buttons by automatically detecting them
-- and clicking them for you on demand.
--
-- @module go_next_prev
-- @copyright 2009 Aldrik Dunbar  (n30n)
-- @copyright 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com>

local lousy = require("lousy")
local binds = require("binds")
local add_binds = binds.add_binds

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
        var els = document.getElementsByTagName("a"), i = els.length;
        while ((e = els[--i])) {
            if (e.text.search(/(\blearn\b|\blast\b|\bimages\b)/i) > -1) {
            } else if (e.text.search(/(\bnext\b|^>$|^(>>|»)$|^(>|»)|(>|»)$|\bmore\b)/i) > -1) {
                click(e);
                break;
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
        var els = document.getElementsByTagName("a"), i = els.length;
        while ((e = els[--i])) {
            if (e.text.search(/(\b(prev|previous)\b|^<$|^(<<|«)$|^(<|«)|(<|«)$)/i) > -1) {
                click(e);
                break;
            }
        }
    }
})();
]=]

-- Add `[[` & `]]` bindings to the normal mode.
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^%]%]$", "Open the next page in the current tab.",
        function (w) w.view:eval_js(go_next, { no_return = true }) end),
    buf("^%[%[$", "Open the previous page in the current tab.",
        function (w) w.view:eval_js(go_prev, { no_return = true }) end),
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
