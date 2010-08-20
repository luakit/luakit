-- Default luakit theme
return {
    -- Default settings
    font = "monospace normal 9",
    fg   = "#fff",
    bg   = "#000",

    -- General settings
    statusbar_fg = "#fff",
    statusbar_bg = "#000",
    inputbar_fg  = "#000",
    inputbar_bg  = "#fff",

    -- Specific settings
    loaded_fg            = "#33AADD",
    tablabel_fg          = "#999",
    tablabel_bg          = "#111",
    selected_tablabel_fg = "#fff",
    selected_tablabel_bg = "#000",

    -- Enforce a minimum tab width of 30 characters to prevent longer tab
    -- titles overshadowing small tab titles when things get crowded.
    tablabel_format      = "%-30s",
}

-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
