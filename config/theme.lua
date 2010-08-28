--------------------------
-- Default luakit theme --
--------------------------

theme = {}

-- Default settings
theme.font = "monospace normal 9"
theme.fg   = "#fff"
theme.bg   = "#000"

-- Statusbar specific
theme.sbar_fg           = "#fff"
theme.sbar_bg           = "#000"
theme.loaded_sbar_fg    = "#33AADD"

-- Input bar specific
theme.ibar_fg           = "#000"
theme.ibar_bg           = "#fff"

-- Tab label
theme.tab_fg            = "#888"
theme.tab_bg            = "#222"
theme.selected_fg       = "#fff"
theme.selected_bg       = "#000"

-- Trusted/untrusted ssl colours
theme.trust_fg          = "#0F0"
theme.notrust_fg        = "#F00"

return theme
-- vim: et:sw=4:ts=8:sts=4:tw=80
