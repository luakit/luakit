-- Default luakit theme
return lousy.theme.from_table({
    -- Default settings
    font = "monospace normal 9",
    fg   = "#fff",
    bg   = "#000",

    -- Statusbar specific
    sbar_fg         = "#fff",
    sbar_bg         = "#000",
    loaded_sbar_fg  = "#33AADD",

    -- Input bar specific
    ibar_fg         = "#000",
    ibar_bg         = "#fff",

    -- Tab label specific
    tab_fg          = "#999",
    tab_bg          = "#111",
    selected_tab_fg = "#fff",
    selected_tab_bg = "#000",
})

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
