----------------------------------------------------------------
-- Follow "next" or "prev" links on a page                    --
-- © 2009 Aldrik Dunbar  (n30n)                               --
-- © 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
----------------------------------------------------------------

local go_next = [=[
(function() {
    var el = document.querySelector("[rel='next']");
    if (el) { // Wow a developer that knows what he's doing!
        location = el.href;
    }
    else { // Search from the bottom of the page up for a next link.
        var els = document.getElementsByTagName("a");
        var i = els.length;
        while ((el = els[--i])) {
            if (el.text.search(/(\bnext\b|^>$|^(>>|»)$|^(>|»)|(>|»)$|\bmore\b)/i) > -1) {
                location = el.href;
                break;
            }
        }
    }
})();
]=]

local go_prev = [=[
(function() {
    var el = document.querySelector("[rel='prev']");
    if (el) {
        location = el.href;
    }
    else {
        var els = document.getElementsByTagName("a");
        var i = els.length;
        while ((el = els[--i])) {
            if (el.text.search(/(\b(prev|previous)\b|^<$|^(<<|«)$|^(<|«)|(<|«)$)/i) > -1) {
                location = el.href;
                break;
            }
        }
    }
})();
]=]

-- Add `[[` & `]]` bindings to the normal mode.
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^%]%]$", function (w) w:eval_js(go_next) end),
    buf("^%[%[$", function (w) w:eval_js(go_prev) end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
