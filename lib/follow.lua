---------------------------------------------------------
-- Vimperator-like link following script for luakit    --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

-- TODO use all frames
-- TODO test with frames
-- TODO different label generators
-- TODO different matching algorithms
-- TODO contenteditable?

-- Main link following javascript.
local follow_js = [=[
    // Global wrapper in order to not disturb main site JS.
    window.follow = (function () {
        // Private members.

        function unlink(element) {
            if (element && element.parentNode) {
                element.parentNode.removeChild(element);
            }
        }

        function isFrame(element) {
            return (element.tagName == "FRAME" || element.tagName == "IFRAME");
        }

        // Returns the visible text of the element based on its class.
        function getText(element) {
            var tag = element.tagName.toLowerCase()
            if ("input" === tag && /text|search|radio|file|button|submit|reset/i.test(element.type)) {
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

            function createTick(hint) {
                var tick = createSpan(hint, follow.theme.horiz_offset, follow.theme.vert_offset - hint.rect.height/2);
                tick.style.font = follow.theme.tick_font;
                tick.style.color = follow.theme.tick_fg;
                if (isFrame(hint.element)) {
                    tick.style.backgroundColor = follow.theme.tick_frame_bg;
                } else {
                    tick.style.backgroundColor = follow.theme.tick_bg;
                }
                tick.style.opacity = follow.theme.tick_opacity;
                tick.style.border = follow.theme.tick_border;
                tick.style.zIndex = 10001;
                tick.style.visibility = 'visible';
                tick.addEventListener('click', function() { click(tick.element); }, false );
                return tick;
            }

            function createOverlay(hint) {
                var overlay = createSpan(hint, 0, 0);
                overlay.style.width = hint.rect.width + "px";
                overlay.style.height = hint.rect.height + "px";
                overlay.style.opacity = follow.theme.opacity;
                overlay.style.border = follow.theme.border;
                overlay.style.backgroundColor = follow.theme.normal_bg;
                overlay.style.zIndex = 10000;
                overlay.style.visibility = 'visible';
                if (isFrame(hint.element)) {
                    overlay.style.display = 'none';
                }
                overlay.addEventListener('click', function() { click(hint.element); }, false );
                return overlay;
            }

            this.tick = createTick(this);
            this.overlay = createOverlay(this);

            follow.tickParent.appendChild(this.tick);
            follow.overlayParent.appendChild(this.overlay);

            this.id = null;
            this.visible = true;

            // Shows the hint.
            this.show = function () {
                this.tick.style.visibility = 'visible';
                this.overlay.style.visibility = 'visible';
                this.visible = true;
            };

            // Hides the hint.
            this.hide = function () {
                this.tick.style.visibility = 'hidden';
                this.overlay.style.visibility = 'hidden';
                this.deactivate();
                this.visible = false;
            };

            // Sets the ID of the hint (the content of the tick label).
            this.setId = function (id) {
                this.id = id;
                this.tick.textContent = id;
            };

            // Changes the appearance of the hint to indicate it is active.
            this.activate = function () {
                this.overlay.style.backgroundColor = follow.theme.focus_bg;
                this.overlay.focus();
                follow.activeHint = this;
            };

            // Changes the appearance of the hint to indicate it is not active.
            this.deactivate = function () {
                this.overlay.style.backgroundColor = follow.theme.normal_bg;
            };

            // Tests if the hint's text matches the given string.
            this.matches = function (str) {
                var text = getText(this.element).toLowerCase();
                return text.indexOf(str) !== -1;
            };
        }

        // Public structure.
        return {
            evaluator: null,

            theme: {},
            hints: [],
            overlayParent: null,
            tickParent: null,
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
                if (!follow.tickParent) {
                    var tickParent = document.createElement("div");
                    document.body.appendChild(tickParent);
                    follow.tickParent = tickParent;
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
                unlink(follow.tickParent);
                unlink(follow.overlayParent);
                follow.init();
            },

            // Gets all visible elements using the selector and builds
            // hints for them. Returns the number of hints generated.
            match: function (selector) {
                var elements = getVisibleElements(selector);
                follow.hints = elements.map(function (element) {
                    return new Hint(element);
                });
                if (elements.length > 0) {
                    follow.hints[0].activate();
                }
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

            // Filters the hints according to the given string
            filter: function (str) {
                var matches = /^(.*?)(\d*)$/.exec(str.toLowerCase())
                var strings = matches[1].split(" ").filter(function (str) {
                    return str !== "";
                });
                var id = matches[2];
                var visibleHints = [];
                var reselect = (follow.activeHint === null);
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
                        visibleHints.push(hint);
                    } else {
                        if (follow.activeHint == hint) {
                            reselect = true;
                        }
                        hint.hide();
                    }
                });
                if (visibleHints.length === 1) {
                    return follow.evaluate(visibleHints[0]);
                } else {
                    // update selection
                    if (reselect && visibleHints.length > 0) {
                        visibleHints[0].activate();
                    }
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

            // Sends a mouse click to the given element.
            click: function (element) {
                var mouseEvent = document.createEvent("MouseEvent");
                mouseEvent.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
                element.dispatchEvent(mouseEvent);
                follow.clear();
            },

            isEditable: function (element) {
                var name = element.tagName.toLowerCase();
                if (name === "textarea" || name === "select") {
                    return true;
                }
                if (name === "input") {
                    var type = element.type.toLowerCase();
                    if (type === 'text' || type === 'search' || type === 'password') {
                        return true;
                    }
                }
                return false;
            },

            // Selects a visible hint according to the given offset.
            focus: function (offset) {
                var currentIdx = null;
                for (var i = 0; i < follow.hints.length; ++i) {
                    var hint = follow.hints[i];
                    if (hint == follow.activeHint) {
                        hint.deactivate();
                        currentIdx = i;
                        break;
                    }
                }
                // work around javascript modulo bug
                var inc = function (v) {
                    var val = v + offset;
                    if (val < 0) {
                        val = follow.hints.length - 1;
                    } else if (val >= follow.hints.length) {
                        val = 0;
                    }
                    return val;
                }
                if (currentIdx !== null) {
                    currentIdx = inc(currentIdx);
                    while (!follow.hints[currentIdx].visible) {
                        currentIdx = inc(currentIdx);
                    }
                    follow.hints[currentIdx].activate();
                }
            },
        }
    })();
]=]

-- Table of following options & modes
follow = {}

follow.default_theme = {
    focus_bg      = "#00ff00";
    normal_bg     = "#ffff99";
    opacity       = 0.3;
    border        = "1px dotted #000000";
    tick_frame_bg = "#552222";
    tick_fg       = "#ffffff";
    tick_bg       = "#000088";
    tick_border   = "2px dashed #000000";
    tick_opacity  = 0.4;
    tick_font     = "11px monospace bold";
    vert_offset   = 0;
    horiz_offset  = -10;
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
            var tag = element.tagName.toLowerCase();
            if (tag === "input" || tag === "textarea" ) {
                var type = element.type.toLowerCase();
                if (type === "radio" || type === "checkbox") {
                    element.checked = !element.checked;
                } else if (type === "submit" || type === "reset" || type  === "button") {
                    follow.click(element);
                } else {
                    element.focus();
                }
            } else {
                follow.click(element);
            }
            if (follow.isEditable(element)) {
                return "form-active";
            } else {
                return "root-active";
            }
        }]=],
    -- Return the uri.
    uri = [=[
        function (element) {
            return element.src || element.href;
        }]=],
    -- Return image location.
    src = [=[
        function (element) {
            return element.src;
        }]=],
    -- Return title or alt tag text.
    desc = [=[
        function (element) {
            return element.title || element.alt || "";
        }]=],
    -- Focus the element.
    focus = [=[
        function (element) {
            element.focus();
            if (follow.isEditable(element)) {
                return "form-active";
            } else {
                return "root-active";
            }
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

--- Generates the labels for the hints. Must return an array of strings with the
-- given size.
function make_labels(size)
    local digits = 1
    while true do
        local max = 10 ^ digits - 10 ^ (digits - 1)
        if max == 9 then max = 10 end
        if max >= size then
            break
        else
            digits = digits + 1
        end
    end
    local start = 10 ^ (digits - 1)
    if start == 1 then start = 0 end
    local labels = {}
    for i=start,size+start-1,1 do
        table.insert(labels, string.reverse(tostring(i)))
    end
    return labels
end

-- Add follow mode binds
add_binds("follow", {
    key({},        "Tab",       function (w) w:eval_js("follow.focus(+1);") end ),
    key({"Shift"}, "Tab",       function (w) w:eval_js("follow.focus(-1);") end ),
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

        -- Load main following js
        local js_blocks = {}
        table.insert(js_blocks, follow_js)

        -- Make theme js
        for k, v in pairs(follow.get_theme()) do
            if type(v) == "number" then
                table.insert(js_blocks, string.format("follow.theme.%s = %s;", k, lousy.util.ntos(v)))
            else
                table.insert(js_blocks, string.format("follow.theme.%s = %q;", k, v))
            end
        end

        -- Load mode specific js
        local evaluator = lousy.util.string.strip(follow.evaluators[mode.evaluator])
        local selector  = follow.selectors[mode.selector],
        table.insert(js_blocks, string.format("follow.evaluator = (%s);", evaluator))
        table.insert(js_blocks, "follow.init();")

        -- Evaluate js code
        local js = table.concat(js_blocks, "\n")
        w:eval_js(js, "(follow.lua)")

        -- Generate labels
        local num = tonumber(w:eval_js(string.format("follow.match(%q);", selector), "(follow.lua)"))
        local labels = make_labels(num)
        state.labels = lousy.util.table.clone(labels)
        state.current = 1
        for i, l in ipairs(labels) do labels[i] = string.format("%q", l) end
        local array = table.concat(labels, ",")
        w:eval_js(string.format("follow.show([%s]);", array), "(follow.lua)")

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
