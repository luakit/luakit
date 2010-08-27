--------------------------
-- Default luakit theme --
--------------------------

theme = {}

-- Default settings
theme.font = "monospace normal 9"
theme.fg   = "#fff"
theme.bg   = "#000"

-- Genaral colors
theme.success_fg = "#0f0"
theme.failure_fg = "#f00"

-- Statusbar specific
theme.sbar_fg         = "#fff"
theme.sbar_bg         = "#000"
theme.loaded_sbar_fg  = "#33AADD"

-- Downloadbar specific
theme.dbar_fg        = "#fff"
theme.dbar_bg        = "#000"
theme.loaded_dbar_fg = "#33AADD"

-- Input bar specific
theme.ibar_fg         = "#000"
theme.ibar_bg         = "#fff"

-- Tab label specific
theme.tab_fg          = "#999"
theme.tab_bg          = "#111"
theme.selected_tab_fg = "#fff"
theme.selected_tab_bg = "#000"

return theme
-- vim: ft=lua:et:sw=4:ts=8:sts=4:tw=80
