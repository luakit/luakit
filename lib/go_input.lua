-------------------------------------------------------------
-- Go to the first input on a page and enter insert mode   --
-- (C) 2009 Aldrik Dunbar  (n30n)                          --
-- (C) 2010 Paweł Zuzelski (pawelz) <pawelz@pld-linux.org> --
-------------------------------------------------------------

local js = [=[
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
    local ret = w:eval_js(string.format("%s(%d);", js, count or 1), "(go_input.lua)")
    w:emit_form_root_active_signal(ret)
end

-- Add `gi` binding to normal mode
add_binds("normal", {
    lousy.bind.buf("^gi$", function (w, b, m) w:go_input(m.count) end, {count=1})
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
