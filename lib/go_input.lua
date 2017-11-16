--- Go to the first input on a page and enter insert mode.
--
-- This module adds a key binding to quickly focus the first text input on a
-- page and enter insert mode. A count is also accepted, which allows choosing a
-- specific text input other than the first.
--
-- @module go_input
-- @copyright 2009 Aldrik Dunbar
-- @copyright 2010 Paweł Zuzelski <pawelz@pld-linux.org>

local webview = require("webview")
local modes = require("modes")
local add_binds = modes.add_binds

local _M = {}

local go_input = [=[
(function (count) {
    var elements = document.querySelectorAll("textarea, input" + [
        ":not([type='button'])", ":not([type='checkbox'])",
        ":not([type='hidden'])", ":not([type='image'])",
        ":not([type='radio'])",  ":not([type='reset'])",
        ":not([type='submit'])", ":not([type='file'])"].join(""));
    if (elements) {
        var el, i = 0, n = 0;
        while((el = elements[i++])) {
            var style = getComputedStyle(el, null);
            if (style.display !== 'none' && style.visibility === 'visible') {
                n++;
                if (n == count) {
                    if (el.type === "file") {
                        el.click();
                    } else {
                        el.focus();
                        el.setSelectionRange(el.value.length, el.value.length);
                        el.scrollIntoViewIfNeeded();
                    }
                    return "form-active";
                }
            }
        }
    }
    return "root-active";
})]=]

-- Add `w:go_input()` webview method
webview.methods.go_input = function(_, w, count)
    local js = string.format("%s(%d);", go_input, count or 1)
    w.view:eval_js(js, { callback = function(ret)
        w:emit_form_root_active_signal(ret)
    end})
end

-- Add `gi` binding to normal mode
add_binds("normal", {
    { "gi", "Focus the first text input on the current page and enter insert mode.",
        function (w, _, m) w:go_input(m.count) end, {count=1} }
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
