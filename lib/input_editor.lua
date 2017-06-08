
local string    = string
local add_binds = add_binds
local key       = lousy.bind.key
local luakit    = luakit

module("input_editor")

local regexp = {
    word = { backward = [[\w+\s*$]], forward = [[^\s*\w+]] },
    char = { backward = [[.$]],      forward = [[^.]]      },
    line = { backward = [[^.*]],     forward = [[.*$]]     },
}

local delete = function(w, action, direction)
    if direction ~= "forward" and direction ~= "backward" then direction = "backward" end
    w:eval_js(string.format([=[
        var e = document.activeElement
        if (e && (e.tagName && 'TEXTAREA' == e.tagName || e.type && 'text' == e.type)) {
            var text = e.value
            var pos  = e.selectionStart
            var forward  = text.substring(pos)
            var backward = text.substring(0, pos)
            var %s = %s.replace(/%s/, '')
            e.value = backward + forward
            e.selectionStart = backward.length
            e.selectionEnd   = backward.length
        }
    ]=], direction, direction, regexp[action][direction]))
end

local paste = function(w, selection)
    if selection ~= "primary" and selection ~= "secondary" and selection ~= "clipboard" then
        selection = "clipboard"
    end
    local s = string.format("%q", luakit.get_selection(selection) or '')
    s = s:sub(2, -2):gsub("\\\n", "\\n"):gsub("\\9", "\t")
    w:eval_js(string.format([=[
        var e = document.activeElement
        if (e && (e.tagName && 'TEXTAREA' == e.tagName || e.type && 'text' == e.type)) {
            var text = e.value
            var pos  = e.selectionStart
            var insertion = "%s"
            e.value = text.substring(0, pos) + insertion + text.substring(pos)
            e.selectionStart = pos + insertion.length
        }
    ]=], s))
end

add_binds("insert", {
    key({"Control"}, "w", function (w) delete(w, "word", "backward") end),
    key({"Control"}, "u", function (w) delete(w, "line", "backward") end),
    key({"Control"}, "h", function (w) delete(w, "char", "backward") end),

    key({"Mod1"},    "w", function (w) delete(w, "word", "forward") end),
    key({"Mod1"},    "u", function (w) delete(w, "line", "forward") end),
    key({"Mod1"},    "h", function (w) delete(w, "char", "forward") end),

    key({"Shift"},            "Insert", function (w) paste(w, "primary")   end),
    key({"Shift", "Control"}, "Insert", function (w) paste(w, "clipboard") end),
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
