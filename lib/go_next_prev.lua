------------------------------------------------------------------
-- Follow "next" or "prev" links on a page                      --
-- (C) 2009 Aldrik Dunbar  (n30n)                               --
-- (C) 2010 Mason Larobina (mason-l) <mason.larobina@gmail.com> --
------------------------------------------------------------------

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
            if (el.text.search(/\bnext/i) > -1) {
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
            if (el.text.search(/\bprev/i) > -1) {
                location = el.href;
                break;
            }
        }
    }
})();
]=]

-- Add `[[` & `]]` bindings to the normal mode.
for _, b in ipairs({
    lousy.bind.buf("^%]%]$", function (w) w:eval_js(go_next) end),
    lousy.bind.buf("^%[%[$", function (w) w:eval_js(go_prev) end),
}) do table.insert(binds.mode_binds.normal, b) end
