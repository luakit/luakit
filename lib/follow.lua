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
  var active;
  var lastpos = 0;
  var last_input = "";
  var last_strings = [];

  function isFrame(element) {
    return (element.tagName == "FRAME" || element.tagName == "IFRAME");
  }

  function get_document(element) {
    if (isFrame(element)) {
      return element.contentDocument;
    } else {
      var doc = element;
      while (doc.parentNode !== null) {
        doc = doc.parentNode;
      }
      return doc;
    }
  }

  function documents() {
    var docs = [top.document];
    var frames = window.frames;
    for (var i = 0; i < frames.length; ++i) {
      var doc = frames[i].document;
      if (doc) {
        docs.push(doc);
      }
    }
    return docs;
  }

  function query(selector) {
    var res = [];
    documents().forEach(function (doc) {
      var set = doc.body.querySelectorAll(selector);
      for (var i = 0; i < set.length; ++i) {
        res.push(set[i]);
      }
    });
    return res;
  }

  function getHints(element) {
    var document = get_document(element);
    return document.hints;
  }

  function getOverlays(element) {
    var document = get_document(element);
    return document.overlays;
  }

  function Hint(element) {
    this.element = element;
    this.rect = element.getBoundingClientRect();

    function create_span(element, h, v) {
      var document = get_document(element.element);
      var span = document.createElement("span");
      var leftpos, toppos;
      if (isFrame(element.element)) {
        leftpos = document.defaultView.scrollX + h;
        toppos = document.defaultView.scrollY + v;
      } else {
        leftpos = Math.max((element.rect.left + document.defaultView.scrollX), document.defaultView.scrollX) + h;
        toppos = Math.max((element.rect.top + document.defaultView.scrollY), document.defaultView.scrollY) + v;
      }
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
      overlay.style.backgroundColor = normal_bg;
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
      e.overlay.style.backgroundColor = normal_bg;
      if (!e.hint.parentNode  && !e.hint.firstchild) {
        var content = document.createTextNode(start + i);
        e.hint.appendChild(content);
        getHints(e.element).appendChild(e.hint);
      }
      else if (!keep) {
        e.hint.textContent = start + i;
      }
      if (!e.overlay.parentNode && !e.overlay.firstchild) {
        getOverlays(e.element).appendChild(e.overlay);
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
      active.overlay.style.backgroundColor = focus_bg;
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
      // create hints and overlay divs for all frames
      documents().forEach(function (doc) {
        var hints = doc.createElement("div");
        var overlays = doc.createElement("div");
        doc.body.appendChild(hints);
        doc.body.appendChild(overlays);
        doc.hints = hints;
        doc.overlays = overlays;
      });
      var res = query(selector);
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
    }
  }

  function is_input(element) {
    var e = element.element;
    if (e.tagName == "INPUT" || e.tagName == "TEXTAREA" ) {
      var type = e.type.toLowerCase();
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
    if (name == "textarea" || name == "select") {
      return true;
    }
    if (name == "input") {
      var type = e.type.toLowerCase();
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
    documents().forEach(function (doc) {
      var hints = doc.hints;
      var overlays = doc.overlays;
      if (overlays && overlays.parentNode) {
        overlays.parentNode.removeChild(overlays);
      }
      if (hints && hints.parentNode) {
        hints.parentNode.removeChild(hints);
      }
    });
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
    active_arr[lastpos].overlay.style.backgroundColor = normal_bg;
    active_arr[newpos].overlay.style.backgroundColor = focus_bg;
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

follow.default_theme = {
    focus_bg     = "#00ff00";
    normal_bg    = "#ffff99";
    opacity      = 0.3;
    border       = "1px dotted #000000";
    hint_fg      = "#ffffff";
    hint_bg      = "#000088";
    hint_border  = "2px dashed #000000";
    hint_opacity = 0.4;
    hint_font    = "11px monospace bold";
    vert_offset  = 0;
    horiz_offset = -10;
}

-- Merge `theme.follow` table with `follow.default_theme`
function follow.get_theme()
    return lousy.util.table.join(follow.default_theme, theme.follow or {})
end

-- Selectors for the different modes
follow.selectors = {
    followable  = 'a, area, textarea, select, input:not([type=hidden]), button';
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
          if (!is_input(element))
            click_element(element);
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
webview.methods.start_follow = function (view, w, mode, prompt, func, count)
    w.follow_state = { mode = mode, prompt = prompt, func = func, count = count }
    w:set_mode("follow")
end

-- Add link following binds
local mode_binds, join, buf, key = binds.mode_binds, lousy.util.table.join, lousy.bind.buf, lousy.bind.key
mode_binds.normal = join(mode_binds.normal or {}, {
    --                           w:start_follow(mode,     prompt,       callback, count)
    -- Follow link
    buf("^f$",  function (w,b,m) w:start_follow("follow", nil,          function (sig) return sig end) end),

    -- Focus element
    buf("^;;$", function (w,b,m) w:start_follow("focus",  "focus",      function (sig) return sig end) end),

    -- Open new tab (optionally [count] times)
    buf("^F$",  function (w,b,m) w:start_follow("uri", (m.count and "open "..m.count.." tab(s)") or "open tab",
                    function (uri, s)
                        for i=1,(s.count or 1) do w:new_tab(uri, false) end
                        return "root-active"
                    end, m.count) end),

    -- Follow a sequence of <CR> delimited hints in background tabs.
    buf("^;F$", function (w,b,m) w:start_follow("uri",    "multi tab",  function (uri, s) w:new_tab(uri, false) w:set_mode("follow") end) end),

    -- Yank uri or desc into primary selection
    buf("^;y$", function (w,b,m) w:start_follow("uri",    "yank",       function (uri)  w:set_selection(uri)  return "root-active" end) end),
    buf("^;Y$", function (w,b,m) w:start_follow("desc",   "yank desc",  function (desc) w:set_selection(desc) return "root-active" end) end),

    -- Download uri
    buf("^;s$", function (w,b,m) w:start_follow("uri",    "download",   function (uri)  w:download(uri)       return "root-active" end) end),

    -- Open image src
    buf("^;i$", function (w,b,m) w:start_follow("image",  "open image", function (src)  w:navigate(src)       return "root-active" end) end),
    buf("^;I$", function (w,b,m) w:start_follow("image",  "tab image",  function (src)  w:new_tab(src)        return "root-active" end) end),

    -- Open, open in new tab or open in new window
    buf("^;o$", function (w,b,m) w:start_follow("uri",    "open",       function (uri)  w:navigate(uri)       return "root-active" end) end),
    buf("^;t$", function (w,b,m) w:start_follow("uri",    "open tab",   function (uri)  w:new_tab(uri)        return "root-active" end) end),
    buf("^;b$", function (w,b,m) w:start_follow("uri",    "open bg tab",function (uri)  w:new_tab(uri, false) return "root-active" end) end),
    buf("^;w$", function (w,b,m) w:start_follow("uri",    "open window",function (uri)  window.new{uri}       return "root-active" end) end),

    -- Set command `:open <uri>`, `:tabopen <uri>` or `:winopen <uri>`
    buf("^;O$", function (w,b,m) w:start_follow("uri",    ":open",      function (uri)  w:enter_cmd(":open "   ..uri) end) end),
    buf("^;T$", function (w,b,m) w:start_follow("uri",    ":tabopen",   function (uri)  w:enter_cmd(":tabopen "..uri) end) end),
    buf("^;W$", function (w,b,m) w:start_follow("uri",    ":winopen",   function (uri)  w:enter_cmd(":winopen "..uri) end) end),
})
-- Add follow mode binds
mode_binds.follow = join(mode_binds.follow or {}, {
    key({},        "Tab",       function (w) w:eval_js("focus_next();") end),
    key({"Shift"}, "Tab",       function (w) w:eval_js("focus_prev();") end),
    key({},        "Return",    function (w)
                                    local s = (w.follow_state or {})
                                    local sig = s.func(w:eval_js("get_active();"), s)
                                    if sig then w:emit_form_root_active_signal(sig) end
                                end),
})

-- Setup follow mode
new_mode("follow", {
    -- Enter follow mode hook
    enter = function (w)
        -- Get following state & options
        if not w.follow_state then w.follow_state = {} end
        local state = w.follow_state
        local mode = follow.modes[state.mode or "follow"]
        -- Get follow mode table
        if not mode then w:set_mode() return error("unknown follow mode") end

        -- Make theme js
        local js_blocks = {}
        for k, v in pairs(follow.get_theme()) do
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
            if state.func then sig = state.func(ret, state) end
            if sig then w:emit_form_root_active_signal(sig) end
        end
    end,
})
