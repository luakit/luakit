--- Userscript support for luakit.
--
-- Evaluates and manages userscripts.
-- JavaScript userscripts must end in <code>.user.js</code>
--
-- # Files and Directories
--
-- - Userscript files should be placed in the `scripts` sub-directory of the
--   luakit data directory, and must have a filename ending in `.user.js`.
--
-- @module userscripts
-- @copyright 2011 Constantin Schomburg <me@xconstruct.net>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2010 Mason Larobina  <mason.larobina@gmail.com>

local webview = require("webview")
local window = require("window")
local util = require("lousy.util")
local lfs = require("lfs")
local new_mode = require("modes").new_mode
local binds, modes = require("binds"), require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds
local menu_binds = binds.menu_binds

local _M = {}

-- Pure JavaScript implementation of greasemonkey methods commonly used
-- in chome/firefox userscripts.
local gm_functions = [=[
  // (C) 2009 Jim Tuttle (http://userscripts.org/users/79247)
  // Original source: http://userscripts.org/scripts/review/41441
  if(typeof GM_getValue === "undefined") {
    GM_getValue = function(name){
      var nameEQ = escape("_greasekit" + name) + "=", ca = document.cookie.split(';');
      for (var i = 0, c; i < ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ') c = c.substring(1, c.length);
        if (c.indexOf(nameEQ) == 0) {
          var value = unescape(c.substring(nameEQ.length, c.length));
          //alert(name + ": " + value);
          return value;
        }
      }
      return null;
    }
  }

  if(typeof GM_setValue === "undefined") {
    GM_setValue = function( name, value, options ){
      options = (options || {});
      if ( options.expiresInOneYear ){
        var today = new Date();
        today.setFullYear(today.getFullYear()+1, today.getMonth, today.getDay());
        options.expires = today;
      }
      var curCookie = escape("_greasekit" + name) + "=" + escape(value) +
      ((options.expires) ? "; expires=" + options.expires.toGMTString() : "") +
      ((options.path)    ? "; path="    + options.path : "") +
      ((options.domain)  ? "; domain="  + options.domain : "") +
      ((options.secure)  ? "; secure" : "");
      document.cookie = curCookie;
    }
  }

  if(typeof GM_xmlhttpRequest === "undefined") {
    GM_xmlhttpRequest = function(/* object */ details) {
      details.method = details.method.toUpperCase() || "GET";
      if(!details.url) {
        throw("GM_xmlhttpRequest requires an URL.");
        return;
      }
      // build XMLHttpRequest object
      var oXhr, aAjaxes = [];
      if(typeof ActiveXObject !== "undefined") {
        var oCls = ActiveXObject;
        aAjaxes[aAjaxes.length] = {cls:oCls, arg:"Microsoft.XMLHTTP"};
        aAjaxes[aAjaxes.length] = {cls:oCls, arg:"Msxml2.XMLHTTP"};
        aAjaxes[aAjaxes.length] = {cls:oCls, arg:"Msxml2.XMLHTTP.3.0"};
      }
      if(typeof XMLHttpRequest !== "undefined")
        aAjaxes[aAjaxes.length] = {cls:XMLHttpRequest, arg:undefined};
      for(var i=aAjaxes.length; i--; )
        try{
          oXhr = new aAjaxes[i].cls(aAjaxes[i].arg);
          if(oXhr) break;
        } catch(e) {}
      // run it
      if(oXhr) {
        if("onreadystatechange" in details)
          oXhr.onreadystatechange = function()
            { details.onreadystatechange(oXhr) };
        if("onload" in details)
          oXhr.onload = function() { details.onload(oXhr) };
        if("onerror" in details)
          oXhr.onerror = function() { details.onerror(oXhr) };
        oXhr.open(details.method, details.url, true);
        if("headers" in details)
          for(var header in details.headers)
            oXhr.setRequestHeader(header, details.headers[header]);
        if("data" in details)
          oXhr.send(details.data);
        else
          oXhr.send();
      }
      else {
        throw ("This Browser is not supported, please upgrade.");
      }
    }
  }

  if(typeof GM_addStyle === "undefined") {
    GM_addStyle = function(/* String */ styles) {
      var oStyle = document.createElement("style");
      oStyle.setAttribute("type", "text\/css");
      oStyle.appendChild(document.createTextNode(styles));
      var parent = document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0];
      parent.appendChild(oStyle);
    }
  }

  if(typeof GM_log === "undefined") {
    GM_log = function(log) {
      if(console)
        console.log(log);
      else
        alert(log);
    }
  }
]=]

--- Stores all the scripts.
local scripts = {}

--- Stores information on the currently loaded scripts on a webview widget
local lstate = setmetatable({}, { __mode = "k" })

--- The directory in which to search for userscripts.
-- By default, this is the `scripts` directory in the luakit data directory.
-- @type string
-- @readonly
_M.dir = luakit.data_dir .. "/scripts"

-- Userscript class methods
local prototype = {
    -- Run the userscript on the given webview widget
    run = function (s, view)
        -- Load common greasemonkey methods
        if not lstate[view].gmloaded then
            view:eval_js(gm_functions, { no_return = true })
            lstate[view].gmloaded = true
        end
        view:eval_js(s.js, { source = s.file, no_return = true, callback =
        function (_, err)
            for _, w in pairs(window.bywidget) do
                if w.view == view then
                    w:error(string.format("running userscript '%s' failed:\n%s",
                    s.file, err))
                end
            end
        end})
        lstate[view].loaded[s.file] = s
    end,
    -- Check if the given uri matches the userscripts include/exclude patterns
    match = function (s, uri)
        local matches = false
        for _, p in ipairs(s.include) do
            if string.match(uri, p) then
                matches = true
                break
            end
        end
        if matches then
            for _, p in ipairs(s.exclude) do
                if string.match(uri, p) then return false end
            end
        end
        return matches
    end,
}

-- Parse and convert a simple glob matching pattern in the `@include`,
-- `@exclude` or `@match` userscript header options into an RE.
local function parse_pattern(pat)
    pat = string.gsub(string.gsub(pat, "[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1"), "*", ".*")
    return '^' .. pat .. '$'
end

local function parse_header(header, file)
    local ret = { file = file, include = {}, exclude = {} }
    for _, line in ipairs(util.string.split(header, "\n")) do
        local singles = { name = true, description = true,
            version = true, homepage = true }
        -- Parse `// @key value` lines in header.
        local key, val = string.match(line, "^// @([%w%-]+)%s+(.+)$")
        if key then
            val = util.string.strip(val or "")
            if singles[key] then
                -- Only grab the first of its kind
                if not ret[key] then ret[key] = val end
            elseif key == "include" or key == "exclude" then
                table.insert(ret[key], parse_pattern(val))
            elseif key == "run-at" and val == "document-start" then
                ret.on_start = true
            end
        end
    end
    return ret
end

--- Loads a js userscript.
local function load_js(file)
    -- Open script
    local f = io.open(file, "r")
    local js = f:read("*all")
    f:close()

    -- Inspect userscript header
    local header = string.match(js, "//%s*==UserScript==%s*\n(.*)\n//%s*==/UserScript==")
    if header then
        local script = parse_header(header, file)
        script.js = js
        script.file = file
        scripts[file] = setmetatable(script, { __index = prototype })
    else
        msg.warn("invalid userscript header in file: %s", file)
    end
end

--- Loads all userscripts from the <code>_M.dir</code>.
local function load_all()
    if not os.exists(_M.dir) then return end
    for file in lfs.dir(_M.dir) do
        if string.match(file, "%.user%.js$") then
            load_js(_M.dir .. "/" .. file)
        end
    end
end

local function view_has_userscripts(view)
    local uri = view.uri or "about:blank"
    for _, script in pairs(scripts) do
        if script:match(uri) then
            return true
        end
    end
    return false
end

-- Invoke all userscripts for a given webviews current uri
local function invoke(view, on_start)
    local uri = view.uri or "about:blank"
    for _, script in pairs(scripts) do
        if on_start == script.on_start then
            if script:match(uri) then
                script:run(view)
            end
        end
    end
end

--- Save a userscript to a file.
-- @tparam string file The file path in which to save the userscript.
-- @tparam string js The userscript contents.
function _M.save(file, js)
    if not os.exists(_M.dir) then
        util.mkdir(_M.dir)
    end
    local f = io.open(_M.dir .. "/" .. file, "w")
    f:write(js)
    f:close()
    load_js(_M.dir .. "/" .. file)
end

--- Delete a userscript file.
-- @tparam string file The file path of the userscript to remove.
function _M.del(file)
    if not scripts[file] then return end
    os.remove(file)
    scripts[file] = nil
end

-- Hook on the webview's load-status signal to invoke the userscripts.
webview.add_signal("init", function (view)
    view:add_signal("load-status", function (v, status)
        if status == "provisional" then
            -- Clear last userscript-loaded state
            lstate[v] = { loaded = {}, gmloaded = false }
-- TODO
--        elseif status == "first-visual" then
--            invoke(v, true)
        elseif status == "finished" then
            if view_has_userscripts(view) then
                if v:emit_signal("enable-userscripts") == false then
                    return
                end
            end
            -- WebKit2 has no first-visual signal, so we can't inject
            -- userscripts set to run at document start that way. Just
            -- inject them all when loading has finished for now.
            invoke(v, true)
            invoke(v)
        end
    end)
end)

-- Add userscript commands
add_cmds({
    -- Saves the content of the open view as an userscript
    { ":userscriptinstall, :usi, :usinstall", "Install the userscript loaded in the current tab.", function (w)
        local view = w.view
        local file = string.match(view.uri, "/([^/]+%.user%.js)$")
        if (not file) then return w:error("URL is not a *.user.js file") end
        if view:loading() then w:error("Wait for script to finish loading first.") end
        local js = "document.body.getElementsByTagName('pre')[0].innerHTML"
        view:eval_js(js, { callback = function(ret)
            local script = util.unescape(ret)
            local header = string.match(script, "//%s*==UserScript==%s*\n(.*)\n//%s*==/UserScript==")
            if not header then return w:error("Could not find userscript header") end
            _M.save(file, script)
            w:notify("Installed userscript to: " .. _M.dir .. "/" .. file)
        end})
    end },

    { ":userscripts, :uscripts", "List installed userscripts.",
        function (w) w:set_mode("uscriptlist") end },
})

-- Add mode to display all userscripts in menu
new_mode("uscriptlist", {
    enter = function (w)
        local rows = {{ "Userscripts", "Description", title = true }}
        for file, script in pairs(scripts) do
            local active = script:match(w.view.uri) and "*" or " "
            local title = (script.name or file) .. " " .. (script.version or "")
            table.insert(rows, { " " .. active .. title, " " .. script.description, script = script })
        end
        if #rows == 1 then
            w:notify(string.format("No userscripts installed. Use `:usinstall`"
                .. "or place .user.js files in %q manually.", _M.dir))
            return
        end
        w.menu:build(rows)
        w:notify("Use j/k to move, d delete, o visit website, t tabopen, w winopen. '*' indicates active scripts.",
            false)
    end,

    leave = function (w)
        w.menu:hide()
    end,
})

add_binds("uscriptlist", util.table.join({
    -- Delete userscript
    { "d", "Delete the currently highlighted userscript.",
        function (w)
            local row = w.menu:get()
            if row and row.script then
                _M.del(row.script.file)
                w.menu:del()
            end
        end },

    -- Open userscript homepage
    { "o", "Open the currently highlighted userscript's homepage in the current tab.",
        function (w)
            local row = w.menu:get()
            if row and row.script and row.script.homepage then
                w:navigate(row.script.homepage)
            end
        end },

    -- Open userscript homepage in new tab
    { "t", "Open the currently highlighted userscript's homepage in a new tab.",
        function (w)
            local row = w.menu:get()
            if row and row.script and row.script.homepage then
                w:new_tab(row.script.homepage, { switch = false })
            end
        end },

    -- Open userscript homepage in new window
    { "w", "Open the currently highlighted userscript's homepage in a new window.",
        function (w)
            local row = w.menu:get()
            if row and row.script and row.script.homepage then
                window.new(row.script.homepage)
            end
        end },
}, menu_binds))

-- Initialize the userscripts
load_all()

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
