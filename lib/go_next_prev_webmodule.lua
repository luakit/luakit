local ui_process = ui_process
local page = page

module("go_next_prev_webmodule")

local ui = ui_process()

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
    if (e) // Wow a developer that knows what hes doing!
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

ui:add_signal("go", function(_, view_id, dir)
    local p = page(view_id)
    p:eval_js(dir == "next" and go_next or go_prev)
end)
