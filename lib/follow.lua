---------------------------------------------------------
-- Vimperator-like link following script for luakit    --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

-- Main link following javascript.
local follow_js = [=[

  // Placeholders for the mode specific selectors & evaluators.
  var selector;
  var evaluator;

  var elements = [];
  var active_arr = [];
  var hints;
  var overlays;
  var active;
  var lastpos = 0;
  var last_input = "";
  var last_strings = [];

  function Hint(element) {
    this.element = element;
    this.rect = element.getBoundingClientRect();

    function create_span(element, h, v) {
      var span = document.createElement("span");
      var leftpos = Math.max((element.rect.left + document.defaultView.scrollX), document.defaultView.scrollX) + h;
      var toppos = Math.max((element.rect.top + document.defaultView.scrollY), document.defaultView.scrollY) + v;
      span.style.position = "absolute";
      span.style.left = leftpos + "px";
      span.style.top = toppos + "px";
      return span;
    }

    function create_hint(element) {
      var hint = create_span(element, horiz_offset, vert_offset - element.rect.height/2);
      hint.style.font = hint_font;
      hint.style.color = hint_fg;
      hint.style.background = hint_bg;
      hint.style.opacity = hint_opacity;
      hint.style.border = hint_border;
      hint.style.zIndex = 10001;
      hint.style.visibility = 'visible';
      return hint;
    }

    function create_overlay(element) {
      var overlay = create_span(element, 0, 0);
      overlay.style.width = element.rect.width + "px";
      overlay.style.height = element.rect.height + "px";
      overlay.style.opacity = opacity;
      overlay.style.backgroundColor = normal_color;
      overlay.style.border = border;
      overlay.style.zIndex = 10000;
      overlay.style.visibility = 'visible';
      overlay.addEventListener( 'click', function() { click_element(element); }, false );
      return overlay;
    }

    this.hint = create_hint(this);
    this.overlay = create_overlay(this);
  }

  function reload_hints(array, input, keep) {
    var length = array.length;
    var start = length < 10 ? 1 : length < 100 ? 10 : 100;
    var bestposition = 37;

    for (var i=0; i<length; i++) {
      var e = array[i];
      e.overlay.style.backgroundColor = normal_color;
      if (!e.hint.parentNode  && !e.hint.firstchild) {
        var content = document.createTextNode(start + i);
        e.hint.appendChild(content);
        hints.appendChild(e.hint);
      }
      else if (!keep) {
        e.hint.textContent = start + i;
      }
      if (!e.overlay.parentNode && !e.overlay.firstchild) {
        overlays.appendChild(e.overlay);
      }
      if (input && bestposition != 0) {
        // match word beginnings
        var content = e.element.textContent.toLowerCase().split(" ");
        for (var cl=0; cl<content.length; cl++) {
          if (content[cl].toLowerCase().indexOf(input) == 0) {
            if (cl < bestposition) {
              lastpos = i;
              bestposition = cl;
              break;
            }
          }
        }
      }
    }
    active = array[lastpos];
    if (active)
      active.overlay.style.backgroundColor = focus_color;
  }

  function click_element(e) {
    var mouseEvent = document.createEvent("MouseEvent");
    mouseEvent.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
    e.element.dispatchEvent(mouseEvent);
    clear();
  }

  function show_hints() {
    // check if page has finished loading
    if (!document.activeElement) {
        return;
    }
    document.activeElement.blur();
    if ( elements ) {
      var res = document.body.querySelectorAll(selector);
      hints = document.createElement("div");
      overlays  = document.createElement("div");
      for (var i=0; i<res.length; i++) {
        var e = new Hint(res[i]);
        var rects = e.element.getClientRects()[0];
        var r = e.rect;
        if (!r || r.top > window.innerHeight || r.bottom < 0 || r.left > window.innerWidth ||  r < 0 || !rects ) {
          continue;
        }
        var style = document.defaultView.getComputedStyle(e.element, null);
        if (style.getPropertyValue("visibility") != "visible" || style.getPropertyValue("display") == "none") {
          continue;
        }
        elements.push(e);
      };
      elements.sort( function(a,b) { return a.rect.top - b.rect.top; });
      active_arr = elements;
      reload_hints(elements);
      document.body.appendChild(hints);
      document.body.appendChild(overlays);
    }
  }

  function is_input(element) {
    var e = element.element;
    var type = e.type.toLowerCase();
    if (e.tagName == "INPUT" || e.tagName == "TEXTAREA" ) {
      if (type == "radio" || type == "checkbox") {
        e.checked = !e.checked;
      }
      else if (type == "submit" || type == "reset" || type  == "button") {
        click_element(element);
      }
      else {
        e.focus();
      }
      return true;
    }
    return false;
  }

  function is_editable(element) {
    var e = element.element;
    var name = e.tagName.toLowerCase();
    var type = e.type.toLowerCase();
    if (name == "textarea" || name == "select") {
      return true;
    }
    if (name == "input") {
      if (type == 'text' || type == 'search' || type == 'password') {
        return true;
      }
    }
    return false;
  }

  function update_hints(input) {
    var array = [];
    var text_content;
    var keep = false;
    if (input) {
      input = input.toLowerCase();
    }
    for (var i=0; i<active_arr.length; i++) {
      var e = active_arr[i];
      if (parseInt(input) == input) {
        text_content = e.hint.textContent;
        keep = true;
      }
      else {
        text_content = e.element.textContent.toLowerCase();
      }
      if (text_content.match(input)) {
        array.push(e);
      }
      else {
        e.hint.style.visibility = 'hidden';
        e.overlay.style.visibility = 'hidden';
      }
    }
    active_arr = array;
    if (array.length == 0) {
      clear();
      return false;
    }
    if (array.length == 1) {
      return evaluate(array[0])
    }
    reload_hints(array, input, keep);
    return false;
  }

  function clear() {
    if (overlays && overlays.parentNode) {
        overlays.parentNode.removeChild(overlays);
    }
    if (hints && hints.parentNode) {
        hints.parentNode.removeChild(hints);
    }
    elements = [];
    active_arr = [];
    active = undefined;
  }

  function update(input) {
     var rv;
     input = input.replace(/(\d+)$/, " $1");
     strings = input.split(" ");
     if (input.length < last_input.length || strings.length < last_strings.length) {
        // user removed a char
        clear();
        show_hints();
        for (var i = 0; i < strings.length; i += 1)
          rv = update_hints(strings[i]);
     } else
       rv = update_hints(strings[strings.length-1]);
     last_input = input;
     last_strings = strings;
     return rv;
  }

  function get_active() {
    return evaluate(active);
  }

  function focus(newpos) {
    active_arr[lastpos].overlay.style.backgroundColor = normal_color;
    active_arr[newpos].overlay.style.backgroundColor = focus_color;
    active = active_arr[newpos];
    lastpos = newpos;
  }

  function focus_next() {
    var newpos = lastpos == active_arr.length-1 ? 0 : lastpos + 1;
    focus(newpos);
  }

  function focus_prev() {
    var newpos = lastpos == 0 ? active_arr.length-1 : lastpos - 1;
    focus(newpos);
  }
]=]

local mode_settings_format = [=[
  selector = "{selector}";
  function evaluate(element) {
    var rv = ({evaluator})(element);
    clear();
    return rv;
  }]=]

-- Table of following options & modes
follow = {}

follow.theme = {
    focus_color     = "#00ff00";
    normal_color    = "#ffff99";
    opacity         = 0.3;
    border          = "1px dotted #000000";
    hint_fg         = "#ffffff";
    hint_bg         = "#000088";
    hint_border     = "2px dashed #000000";
    hint_opacity    = 0.4;
    hint_font       = "11px monospace bold";
    vert_offset     = 0;
    horiz_offset    = -10;
}

-- Selectors for the different modes
follow.selectors = {
    followable  = 'a, area, textarea, select, input:not([type=hidden]), button, frame, iframe';
    focusable   = 'a, area, textarea, select, input:not([type=hidden]), button, frame, iframe, applet, object';
    uri         = 'a, area, frame, iframe';
    desc        = '*[title], img[alt], applet[alt], area[alt], input[alt]';
    image       = 'img, input[type=image]';
}

-- Evaluators for the different modes
follow.evaluators = {
    -- Click the element & return form/root active signals
    follow = [=[
        function(element) {
          var e = element.element;
          if (!is_input(element) && e.href) {
            if (e.href.match(/javascript:/) || (e.type.toLowerCase() == "button"))
              click_element(element);
            else
              document.location = e.href;
          }
          if (is_editable(element))
            return "form-active";
          return "root-active";
        }]=],
    -- Return the uri.
    uri = [=[
        function (element) {
          var e = element.element;
          var uri = e.src || e.href;
          if (!uri.match(/javascript:/))
            return uri;
        }]=],
    -- Return image location.
    src = [=[
        function (element) {
          return element.element.src;
        }]=],
    -- Return title or alt tag text.
    desc = [=[
        function (element) {
          var e = element.element;
          return e.title || e.alt || "";
        }]=],
    -- Focus the element.
    focus = [=[
        function (element) {
          element.element.focus();
          if (is_editable(element))
            return "form-active";
          return "root-active";
        }]=],
}

-- Table of modes and their selectors & evaulator functions.
follow.modes = {}

-- Build mode table
for _, t in ipairs({
  -- Follow mode,  Selector name,  Evaluator name
    {"follow",     "followable",   "follow"      },
    {"uri",        "uri",          "uri"         },
    {"desc",       "desc",         "desc"        },
    {"focus",      "focusable",    "focus"       },
    {"image",      "image",        "src"         },
}) do
    follow.modes[t[1]] = { selector = t[2], evaluator = t[3] }
end

-- Add webview methods
webview.methods.start_follow = function (view, w, mode, prompt, func)
    w.follow_state = { mode = mode, prompt = prompt, func = func }
    w:set_mode("follow")
end

-- Add link following binds
local mode_binds, join, buf, key = binds.mode_binds, lousy.util.table.join, lousy.bind.buf, lousy.bind.key
mode_binds.normal = join(mode_binds.normal or {}, {
    --                       w:start_follow(mode,     prompt,             callback)
    buf("^f$",  function (w) w:start_follow("follow", nil,                function (sig)                                return sig           end) end),
    buf("^Ff$", function (w) w:start_follow("focus",  "focus",            function (sig)                                return sig           end) end),
    buf("^Fy$", function (w) w:start_follow("uri",    "yank",             function (uri)  w:set_selection(uri)     return "root-active" end) end),
    buf("^FY$", function (w) w:start_follow("desc",   "yank description", function (desc) w:set_selection(desc)    return "root-active" end) end),
    buf("^Fs$", function (w) w:start_follow("uri",    "download",         function (uri)  w:download(uri)               return "root-active" end) end),
    buf("^Fi$", function (w) w:start_follow("image",  "open image",       function (src)  w:navigate(src)               return "root-active" end) end),
    buf("^Fo$", function (w) w:start_follow("uri",    "open",             function (uri)  w:navigate(uri)               return "root-active" end) end),
    buf("^Ft$", function (w) w:start_follow("uri",    "new tab",          function (uri)  w:new_tab(uri)                return "root-active" end) end),
    buf("^Fw$", function (w) w:start_follow("uri",    "new window",       function (uri)  window.new{uri}               return "root-active" end) end),
    buf("^FO$", function (w) w:start_follow("uri",    "open cmd",         function (uri)  w:enter_cmd(":open "..uri)                         end) end),
    buf("^FT$", function (w) w:start_follow("uri",    "tabopen cmd",      function (uri)  w:enter_cmd(":tabopen "..uri)                      end) end),
    buf("^FW$", function (w) w:start_follow("uri",    "winopen cmd",      function (uri)  w:enter_cmd(":winopen "..uri)                      end) end),
})
-- Add follow mode binds
mode_binds.follow = join(mode_binds.follow or {}, {
    key({},        "Tab",    function (w) w:eval_js("focus_next();") end),
    key({"Shift"}, "Tab",    function (w) w:eval_js("focus_prev();") end),
    key({},        "Return", function (w) w:emit_form_root_active_signal(w.follow_state.func(w:eval_js("get_active();"))) end),
})

-- Setup follow mode
new_mode("follow", {
    -- Enter follow mode hook
    enter = function (w)
        local i, p = w.ibar.input, w.ibar.prompt
        -- Get following state & options
        if not w.follow_state then w.follow_state = {} end
        local state = w.follow_state
        local mode = follow.modes[state.mode or "follow"]
        -- Get follow mode table
        if not mode then w:set_mode() return error("unknown follow mode") end

        -- Make theme js
        local js_blocks = {}
        for k, v in pairs(follow.theme) do
            if type(v) == "number" then
                table.insert(js_blocks, string.format("%s = %f;", k, v))
            else
                table.insert(js_blocks, string.format("%s = %q;", k, v))
            end
        end

        -- Load main following js
        table.insert(js_blocks, follow_js)

        -- Load mode specific js
        local subs = {
            selector  = follow.selectors[mode.selector],
            evaluator = lousy.util.string.strip(follow.evaluators[mode.evaluator]),
        }
        local js, count = string.gsub(mode_settings_format, "{(%w+)}", subs)
        if count ~= 2 then return error("invalid number of substitutions") end
        table.insert(js_blocks, js);

        -- Clear & show hints
        table.insert(js_blocks, "clear();\nshow_hints();")

        -- Evaluate js code
        local js = table.concat(js_blocks, "\n")
        w:eval_js(js, "(follow.lua)")

        -- Set prompt & input text
        w:set_prompt(state.prompt and string.format("Follow (%s):", state.prompt) or "Follow:")
        w:set_input("")
    end,

    -- Leave follow mode hook
    leave = function (w)
        if w.eval_js then w:eval_js("clear();", "(follow.lua)") end
    end,

    -- Input bar changed hook
    changed = function (w, text)
        local ret = w:eval_js(string.format("update(%q);", text), "(follow.lua)")
        local state = w.follow_state or {}
        if ret ~= "false" then
            local sig
            if state.func then sig = state.func(ret) end
            if sig then w:emit_form_root_active_signal(sig) end
        end
    end,
})
