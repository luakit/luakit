----------------------------------------------------------------
-- Follow "next" or "prev" links on a page                    --
-- © 2009 Aldrik Dunbar  (n30n)                               --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
----------------------------------------------------------------

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
            if (e.text.search(/(\bnext\b|^>$|^(>>|»)$|^(>|»)|(>|»)$|\bmore\b)/i) > -1) {
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
    buf("^%]%]$", function (w) w.view:eval_js(go_next) end),
    buf("^%[%[$", function (w) w.view:eval_js(go_prev) end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
