local string = string
local globals = globals
local capi = { luakit = luakit }
local os = os

module "editor"

-- Can't yet handle files with special characters in their name
edit = function (file, line)
	local subs = {
		term = globals.term or os.getenv("TERMINAL") or "xterm",
		editor = globals.editor or os.getenv("EDITOR") or "vim",
		file = file,
		line = line or 0,
	}
	local cmd_tmpl = "{term} -e '{editor} {file} +{line}'"
	local cmd = string.gsub(cmd_tmpl, "{(%w+)}", subs)
	capi.luakit.spawn(cmd)
end
