-----------------------------------------------------------
-- Go to the first input on a page and enter insert mode --
-- © 2009 Aldrik Dunbar  (n30n)                          --
-- © 2010 Paweł Zuzelski (pawelz) <pawelz@pld-linux.org> --
-----------------------------------------------------------

local go_input = [=[
(function (count) {
    var elements = document.querySelectorAll("textarea, input" + [
        ":not([type='button'])", ":not([type='checkbox'])",
        ":not([type='hidden'])", ":not([type='image'])",
        ":not([type='radio'])",  ":not([type='reset'])",
        ":not([type='submit'])"].join(""));
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
                    }
                    return "form-active";
                }
            }
        }
    }
    return "root-active";
})]=]

-- Add `w:go_input()` webview method
webview.methods.go_input = function(view, w, count)
    local js = string.format("%s(%d);", go_input, count or 1)
    w:emit_form_root_active_signal(w.view:eval_js(js))
end

-- Add `gi` binding to normal mode
local buf = lousy.bind.buf
add_binds("normal", {
    buf("^gi$", function (w, b, m)
        w:go_input(m.count)
    end, {count=1})
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
