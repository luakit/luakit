local downloads = {}
local function eventbox() return widget{type="eventbox"} end
local function hbox()     return widget{type="hbox"}     end
local function label()    return widget{type="label"}    end

-- Provides a bar that lists all running downloads.
module("downloadbar")

-- The widget of the download bar.
bar = {
    layout  = hbox(),
    ebox    = eventbox(),
    visible = false,
    hide    = function(bar)
        bar.visible = false
        bar.ebox:hide()
    end,
    show    = function(bar)
        bar.visible = true
        bar.ebox:show()
    end,
}

-- Adds a download to the bar.
function add_download(d)
    local w = label()
    w:set_text(d.uri)
    table.insert(downloads, { download = d, widget = w })
    bar.layout:pack_start(w, false, false, 0)
    bar:show()
end

-- Setup the widgets.
bar.ebox:set_child(bar.layout)
bar:hide()

