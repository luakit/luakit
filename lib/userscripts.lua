-------------------------------------------------------
-- Userscript support for luakit                     --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

-- Grab environment we need
local io = io
local ipairs = ipairs
local os = os
local pairs = pairs
local setmetatable = setmetatable
local string = string
local table = table
local warn = warn
local webview = webview
local util = require("lousy.util")
local lfs = require("lfs")
local capi = { luakit = luakit }

--- Evaluates and manages userscripts.
-- JavaScript userscripts must end in <code>.user.js</code>
module("userscripts")

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
      document.getElementsByTagName("head")[0].appendChild(oStyle);
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

--- The directory, in which to search for userscripts.
-- By default, this is $XDG_DATA_HOME/luakit/scripts
dir = capi.luakit.data_dir .. "/scripts"

-- Userscript class methods
local prototype = {
    -- Run the userscript on the given webview widget
    run = function (s, view)
        -- Load common greasemonkey methods
        if not lstate[view].gmloaded then
            view:eval_js(gm_functions, "(userscript:gm_functions)")
            lstate[view].gmloaded = true
        end
        view:eval_js(s.js, string.format("(userscript:%s)", s.file))
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
    for i, line in ipairs(util.string.split(header, "\n")) do
        -- Parse `// @key value` line in header.
        local key, val = string.match(line, "^// @([%w%-]+)%s+(.+)$")
        if key then
            val = util.string.strip(val or "")
            -- Populate header table
            if key == "name" or key == "description" or key == "version" then
                -- Only grab the first of its kind
                if not ret[key] then ret[key] = val end
            elseif key == "include" or key == "exclude" then
                table.insert(ret[key], parse_pattern(val))
            elseif key == "run-at" and val == "document-start" then
                ret.on_start = true
            end
        else
            warn("(userscripts.lua): Invalid line in header: %s:%d:%s", file, i, line)
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
    local header = string.match(js, "^//%s*==UserScript==%s*\n(.*)\n//%s*==/UserScript==")
    if header then
        local script = parse_header(header, file)
        script.js = js
        scripts[file] = setmetatable(script, { __index = prototype })
    else
        warn("(userscripts.lua): Invalid userscript header in file: %s", file)
    end
end

--- Loads all userscripts from the <code>userscripts.dir</code>.
local function load_all()
    if not os.exists(dir) then return end
    for file in lfs.dir(dir) do
        if string.match(file, "%.user%.js$") then
            load_js(dir .. "/" .. file)
        end
    end
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

--- Hook on the webview's load-status signal to invoke the userscripts.
webview.init_funcs.userscripts = function (view, w)
    view:add_signal("load-status", function (v, status)
        if status == "provisional" then
            -- Clear last userscript-loaded state
            lstate[v] = { loaded = {}, gmloaded = false }
        elseif status == "first-visual" then
            invoke(v, true)
        elseif status == "finished" then
            invoke(v)
        end
    end)
end

-- Initialize the userscripts
load_all()

-- vim: et:sw=4:ts=8:sts=4:tw=80
