--- Edit the contents of text inputs in an external editor.
--
-- This module allows you to edit the contents of the currently focused
-- text input in your preferred text editor. The focused text input is
-- disabled, and a text editor window will open with the current input
-- contents. After you have finished editing, save the file and quit the
-- editor; the text input will be enabled and its contents will be set
-- to that of the saved file.
--
-- @module open_editor

local modes = require("modes")
local editor = require("editor")
local add_binds = modes.add_binds

local _M = {}

local function edit_externally(w)
    local time = os.time()
    local marker = "luakit_extedit_" .. time
    local file = luakit.cache_dir .. "/" .. marker .. ".txt"

    local function editor_callback()
        local f = io.open(file, "r")
        local s = f:read("*all")
        f:close()
        os.remove(file)
        -- Strip the string
        s = s:gsub("^%s*(.-)%s*$", "%1")
        -- Escape it but remove the quotes
        s = string.format("%q", s):sub(2, -2)
        -- lua escaped newlines (slash+newline) into js newlines (slash+n)
        s = s:gsub("\\\n", "\\n")
        w.view:eval_js(string.format([=[
            var e = document.getElementsByClassName('%s');
            if (1 == e.length && e[0].disabled) {
                e[0].focus();
                e[0].value = "%s";
                e[0].disabled = false;
                e[0].className = e[0].className.replace(/\b %s\b/,'');
            }
        ]=], marker, s, marker), { no_return = true })
    end

    w.view:eval_js(string.format([=[
        var e = document.activeElement;
        if (e && ('TEXTAREA' === e.tagName || 'text' === e.type)) {
            var s = e.value;
            e.className += " %s";
            e.disabled = true;
            e.value = 'Editing externally...';
            s;
        } else 'false';
    ]=], marker, file), { callback = function(s)
        if "false" ~= s then
            local f = io.open(file, "w")
            f:write(s)
            f:flush()
            f:close()
            editor.edit(file, 1, editor_callback)
        end
    end })
end

add_binds("insert", {
    { "<Control-e>", "Edit currently focused input in external editor.", edit_externally },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
