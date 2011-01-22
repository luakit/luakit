---------------------------------------------------------
-- Vimperator-like link following script for luakit    --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

-- TODO set active element when changing filter
--      focus next/prev
--      use all frames
--      test with frames

-- Main link following javascript.
local follow_js = [=[
    // Global wrapper in order to not disturb main site JS.
    window.follow = (function () {
        // Private members.

        // Sends a mouse click to the given element.
        function click(element) {
            var mouseEvent = document.createEvent("MouseEvent");
            mouseEvent.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
            element.dispatchEvent(mouseEvent);
            follow.clear();
        }

        // Tests if the element is a frame of some sort.
        function isFrame(element) {
            return (element.tagName == "FRAME" || element.tagName == "IFRAME");
        }

        // Returns the text of the element based on its class.
        function getText(element) {
            var tag = element.tagName.toLowerCase()
            if ("input" === tag && /text|search|radio|file|button|submit|reset/i.matches(element.type)) {
                return element.value;
            } else if ("select" === tag) {
                return element.value;
            } else {
                return element.textContent;
            }
        }

        // Returns all elements within the viewport.
        function getVisibleElements(selector) {
            var elements = [];
            var set = document.body.querySelectorAll(selector);
            for (var i = 0; i < set.length; i++) {
                var e = set[i];
                var rects = e.getClientRects()[0];
                var r = e.getBoundingClientRect();
                // test if in viewport
                if (!r || r.top > window.innerHeight || r.bottom < 0 || r.left > window.innerWidth ||  r < 0 || !rects ) {
                    continue;
                }
                // test if hidden
                var style = document.defaultView.getComputedStyle(e, null);
                if (style.getPropertyValue("visibility") != "visible" || style.getPropertyValue("display") == "none") {
                    continue;
                }
                elements.push(e);
            };
            elements.sort(function (a,b) {
                return a.getBoundingClientRect().left - b.getBoundingClientRect().left;
            });
            elements.sort(function (a,b) {
                return a.getBoundingClientRect().top - b.getBoundingClientRect().top;
            });
            return elements;
        }

        // Hint class. Wraps data and functions related to hint manipulation.
        function Hint(element) {
            this.element = element;
            this.rect = element.getBoundingClientRect();

            // Hint creation helper functions.
            function createSpan(hint, h, v) {
                var span = document.createElement("span");
                var leftpos, toppos;
                if (isFrame(hint.element)) {
                    leftpos = document.defaultView.scrollX + h;
                    toppos = document.defaultView.scrollY + v;
                } else {
                    leftpos = Math.max((hint.rect.left + document.defaultView.scrollX), document.defaultView.scrollX) + h;
                    toppos = Math.max((hint.rect.top + document.defaultView.scrollY), document.defaultView.scrollY) + v;
                }
                // ensure all hints are visible
                leftpos = Math.max(leftpos, 0);
                toppos = Math.max(toppos, 0);
                span.style.position = "absolute";
                span.style.left = leftpos + "px";
                span.style.top = toppos + "px";
                return span;
            }

            function createHint(hint) {
                var hint = createSpan(hint, follow.theme.horiz_offset, follow.theme.vert_offset - hint.rect.height/2);
                hint.style.font = follow.theme.hint_font;
                hint.style.color = follow.theme.hint_fg;
                hint.style.background = follow.theme.hint_bg;
                hint.style.opacity = follow.theme.hint_opacity;
                hint.style.border = follow.theme.hint_border;
                hint.style.zIndex = 10001;
                hint.style.visibility = 'visible';
                hint.addEventListener('click', function() { click(hint.element); }, false );
                return hint;
            }

            function createOverlay(hint) {
                var overlay = createSpan(hint, 0, 0);
                overlay.style.width = hint.rect.width + "px";
                overlay.style.height = hint.rect.height + "px";
                overlay.style.opacity = follow.theme.opacity;
                overlay.style.backgroundColor = follow.theme.normal_bg;
                overlay.style.border = follow.theme.border;
                overlay.style.zIndex = 10000;
                overlay.style.visibility = 'visible';
                overlay.addEventListener('click', function() { click(hint.element); }, false );
                return overlay;
            }

            this.hint = createHint(this);
            this.overlay = createOverlay(this);
            this.id = null;

            // Shows the hint.
            this.show = function () {
                this.hint.style.visibility = 'visible';
                this.overlay.style.visibility = 'visible';
            };

            // Hides the hint.
            this.hide = function () {
                this.hint.style.visibility = 'hidden';
                this.overlay.style.visibility = 'hidden';
            };

            // Sets the ID of the hint (the thing in the top right corner).
            this.setId = function (id) {
                this.id = id;
                this.hint.textContent = id;
            };

            // Changes the appearance of the hint to indicate it is active.
            this.activate = function () {
                this.overlay.style.backgroundColor = follow.theme.normal_bg;
                this.overlay.focus();
                follow.activeHint = this;
            };

            // Changes the appearance of the hint to indicate it is not active.
            this.deactivate = function () {
                this.overlay.style.backgroundColor = follow.theme.focus_bg;
            };

            // Tests if the hint's text matches the given string.
            this.matches = function (str) {
                var text = getText(this.element);
                return text.indexOf(str) !== -1;
            };
        }

        // Public structure.
        return {
            evaluator: null,

            theme: {},
            hints: [],
            overlayParent: null,
            hintParent: null,
            activeHint: null,

            // Ensures the system is initialized.
            // Returns true on success. If false is returned, the other hinting functions
            // cannot be used safely.
            init: function () {
                if (!document.activeElement) {
                    return false;
                }
                follow.hints = [];
                follow.activeHint = null;
                if (!follow.hintParent) {
                    var hints = document.createElement("div");
                    document.body.appendChild(hints);
                    follow.hintParent = hints;
                }
                if (!follow.overlayParent) {
                    var overlays = document.createElement("div");
                    document.body.appendChild(overlays);
                    follow.overlayParent = overlays;
                }
                return true;
            },

            // Removes all hints and resets the system to default.
            clear: function() {
                follow.hintParent.parentNode.removeChild(follow.hintParent);
                follow.overlayParent.parentNode.removeChild(follow.overlayParent);
                init();
            },

            // Gets all visible elements using the selector and builds
            // hints for them. Returns the number of hints generated.
            match: function (selector) {
                var elements = getVisibleElements(selector);
                follow.hints = elements.map(function (element) {
                    var hint = new Hint(element);
                    follow.hintParent.appendChild(hint.hint);
                    follow.overlayParent.appendChild(hint.overlay);
                    return hint;
                });
                return elements.length;
            },

            // Shows all hints and assigns them the given IDs.
            show: function (ids) {
                document.activeElement.blur();
                for (var i = 0; i < ids.length; ++i) {
                    var hint = follow.hints[i];
                    hint.setId(ids[i]);
                    hint.show();
                }
            },

            // Deselects all hints and selects the hint with the given ID, if it exists.
            select: function (id) {
                follow.activeHint = null;
                follow.hints.forEach(function (hint) {
                    if (hint.id === id) {
                        hint.activate();
                    } else {
                        hint.deactivate();
                    }
                });
            },

            // Filters the hints according to the given string
            filter: function (str) {
                var matches = /^(.*?)(\d*)$/.exec(str)
                var strings = matches[1].split(" ").filter(function (str) {
                    return str !== "";
                });
                var id = matches[2];
                var num = 0;
                var lastHint = null;
                follow.hints.forEach(function (hint) {
                    var matches = true;
                    // check text match
                    strings.forEach(function (str) {
                        if (!hint.matches(str)) {
                            matches = false;
                        }
                    });
                    // check ID
                    if (hint.id.substr(0, id.length) !== id) {
                        matches = false;
                    }
                    // update visibility
                    if (matches) {
                        hint.show();
                        lastHint = hint;
                        num += 1;
                    } else {
                        hint.hide();
                    }
                });
                if (num == 1) {
                    follow.evaluate(lastHint);
                }
            },

            // Evaluates the given element or the active element, if none is given.
            evaluate: function (element) {
                var hint = element || follow.activeHint;
                if (hint) {
                    var ret = follow.evaluator(hint.element);
                    follow.clear();
                    return ret;
                }
            },
        }
    })();
]=]

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
    followable  = 'a, area, textarea, select, input:not([type=hidden]), button',
    focusable   = 'a, area, textarea, select, input:not([type=hidden]), button, frame, iframe, applet, object',
    uri         = 'a, area, frame, iframe',
    desc        = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    image       = 'img, input[type=image]',
}

-- Evaluators for the different modes
follow.evaluators = {
    -- Click the element & return form/root active signals
    follow = [=[
        function(element) {
          if (!is_input(element))
            clickElement(element);
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
local buf, key = lousy.bind.buf, lousy.bind.key

add_binds("normal", {
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

    -- Yank uri or desc into primary selection
    buf("^;y$", function (w,b,m) w:start_follow("uri",    "yank",
                    function (uri)
                        w:set_selection(uri)
                        w:notify("Yanked: " .. uri)
                    end) end),

    buf("^;Y$", function (w,b,m) w:start_follow("desc",   "yank desc",
                    function (desc)
                        w:set_selection(desc)
                        w:notify("Yanked: " .. desc)
                    end) end),

    -- Follow a sequence of <CR> delimited hints in background tabs.
    buf("^;F$", function (w,b,m) w:start_follow("uri",    "multi tab",  function (uri, s) w:new_tab(uri, false) w:set_mode("follow") end) end),

    -- Download uri
    buf("^;s$", function (w,b,m) w:start_follow("uri",    "download",   function (uri)  downloads.add(uri)    return "root-active" end) end),

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
add_binds("follow", {
    key({},        "Tab",       function (w) w:eval_js("focus_next();") end),
    key({"Shift"}, "Tab",       function (w) w:eval_js("focus_prev();") end),
    key({},        "Return",    function (w)
                                    local s = (w.follow_state or {})
                                    local sig = s.func(w:eval_js("follow.evaluate();"), s)
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
                table.insert(js_blocks, string.format("follow.theme.%s = %s;", k, lousy.util.ntos(v)))
            else
                table.insert(js_blocks, string.format("follow.theme.%s = %q;", k, v))
            end
        end

        -- Load main following js
        table.insert(js_blocks, follow_js)

        -- Load mode specific js
        local evaluator = lousy.util.string.strip(follow.evaluators[mode.evaluator]),
        local selector  = follow.selectors[mode.selector],
        table.insert(js_blocks, string.printf("follow.evaluator = (%s);", evaluator))
        table.insert(js_blocks, "follow.init();")
        table.insert(js_blocks, string.printf("follow.match(%q);", selector))

        -- Evaluate js code
        local js = table.concat(js_blocks, "\n")
        w:eval_js(js, "(follow.lua)")

        -- Set prompt & input text
        w:set_prompt(state.prompt and string.format("Follow (%s):", state.prompt) or "Follow:")
        w:set_input("")
    end,

    -- Leave follow mode hook
    leave = function (w)
        if w.eval_js then w:eval_js("follow.clear();", "(follow.lua)") end
    end,

    -- Input bar changed hook
    changed = function (w, text)
        local ret = w:eval_js(string.format("follow.filter(%q);", text), "(follow.lua)")
        local state = w.follow_state or {}
        if ret ~= "false" then
            local sig
            if state.func then sig = state.func(ret, state) end
            if sig then w:emit_form_root_active_signal(sig) end
        end
    end,
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
