------------------------------------------------------------------
-- Luakit go_input                                              --
-- (C) 2009 Aldrik Dunbar  (n30)                                --
-- (C) 2010 Paweł Zuzelski (pawelz)      <pawelz@pld-linux.org> --
------------------------------------------------------------------

local go_input = [=[ 
(function() {
    var elements = document.querySelectorAll("textarea, input" + [
        ":not([type='button'])", ":not([type='checkbox'])",
        ":not([type='hidden'])", ":not([type='image'])",
        ":not([type='radio'])",  ":not([type='reset'])",
        ":not([type='submit'])"].join(""));
    if (elements) {
        var el, i = 0;
        while((el = elements[i++])) {
            var style = getComputedStyle(el, null);
            if (style.display !== 'none' && style.visibility === 'visible') {
                if (el.type === "file") {
                    el.click();
                } else {
                    el.focus();
                }
                return "form-active";
            }
        }
    }
    return "root-active";
})();
]=]

-- Add `w:go_input()` method
webview.methods.go_input = function(view, w)
    local ret = w:eval_js(go_input)
    w:emit_form_root_active_signal(ret)
end

-- Add `gi` binding to normal mode
table.insert(binds.mode_binds.normal,
    lousy.bind.buf("^gi$", function (w) w:go_input() end))
