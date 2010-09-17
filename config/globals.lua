-- Global variables for luakit
globals = {
    homepage         = "http://luakit.org/",
 -- homepage         = "http://github.com/mason-larobina/luakit",
    scroll_step      = 20,
    zoom_step        = 0.1,
    max_cmd_history  = 100,
    max_srch_history = 100,
 -- http_proxy       = "http://example.com:3128",
    download_dir     = luakit.get_special_dir("DOWNLOAD") or (os.getenv("HOME") .. "/downloads"),
}

-- Make useragent
local arch = string.match(({luakit.spawn_sync("uname -sm")})[2], "([^\n]*)")
local lkv  = string.format("luakit/%s", luakit.version)
local wkv  = string.format("WebKitGTK+/%d.%d.%d", luakit.webkit_major_version, luakit.webkit_minor_version, luakit.webkit_micro_version)
local awkv = string.format("AppleWebKit/%s.%s+", luakit.webkit_user_agent_major_version, luakit.webkit_user_agent_minor_version)
globals.useragent = string.format("Mozilla/5.0 (%s) %s %s %s", arch, awkv, wkv, lkv)

-- Search common locations for a ca file which is used for ssl connection validation.
local ca_files = {luakit.data_dir .. "/ca-certificates.crt",
    "/etc/certs/ca-certificates.crt", "/etc/ssl/certs/ca-certificates.crt",}
for _, ca_file in ipairs(ca_files) do
    if os.exists(ca_file) then
        globals.ca_file = ca_file
        break
    end
end

-- Change to stop navigation sites with invalid or expired ssl certificates
globals.ssl_strict = false

-- Search engines
search_engines = {
    luakit      = "http://luakit.org/search/index/luakit?q={0}",
    google      = "http://google.com/search?q={0}",
    duckduckgo  = "http://duckduckgo.com/?q={0}",
    wikipedia   = "http://en.wikipedia.org/wiki/Special:Search?search={0}",
    debbugs     = "http://bugs.debian.org/{0}",
    imdb        = "http://imdb.com/find?s=all&q={0}",
    sourceforge = "http://sf.net/search/?words={0}",
}

-- Set google as fallback search engine
search_engines.default = search_engines.google

-- Fake the cookie policy enum here
cookie_policy = { always = 0, never = 1, no_third_party = 2 }

-- Per-domain webview properties
domain_props = { --[[
    ["all"] = {
        ["enable-scripts"]          = false,
        ["enable-plugins"]          = false,
        ["enable-private-browsing"] = false,
        ["user-stylesheet-uri"]     = "",
        ["accept-policy"]           = cookie_policy.never,
    },
    ["youtube.com"] = {
        ["enable-scripts"] = true,
        ["enable-plugins"] = true,
    },
    ["lwn.net"] = {
       ["accept-policy"] = cookie_policy.no_third_party,
    },
    ["forums.archlinux.org"] = {
        ["user-stylesheet-uri"]     = luakit.data_dir .. "/styles/dark.css",
        ["enable-private-browsing"] = true,
    }, ]]
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
