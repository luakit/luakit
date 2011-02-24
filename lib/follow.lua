---------------------------------------------------------
-- Vimperator-like link following script for luakit    --
-- (C) 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- (C) 2010 Mason Larobina  <mason.larobina@gmail.com> --
---------------------------------------------------------

local ipairs = ipairs
local pairs = pairs
local table = table
local string = string
local lousy = require("lousy")
local theme = theme
local math = math
local downloads = downloads
local tonumber, tostring = tonumber, tostring
local webview = webview
local add_binds, new_mode = add_binds, new_mode
local type = type

module("follow")

local clear_js = [=[
    // Remove an element from its parentNode.
    var unlink = function (element) {
        if (element && element.parentNode) {
            element.parentNode.removeChild(element);
        }
    }
    var tickParent;
    var overlayParent;
    if (window.follow) {
        overlayParent = window.follow.overlayParent;
        tickParent = window.follow.tickParent;
    }
    overlayParent = overlayParent || document.getElementById("luakit_follow_overlayParent");
    tickParent = tickParent || document.getElementById("luakit_follow_tickParent");
    unlink(tickParent);
    unlink(overlayParent);
]=]

-- Main link following javascript.
local follow_js = [=[
    // Global wrapper in order to not disturb main site JS.
    window.follow = (function () {
        // Private members.

        // Tests if the given element is a "frame".
        // We select body tags instead of frames to prevent cross-domain javascript requests.
        function isFrame(element) {
            return element.tagName.toLowerCase() == "body"
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

        // Returns all visible elements within the viewport.
        function getVisibleElements(selector) {
            var elements = [];
            var set = document.querySelectorAll(selector);
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
            // sort top to bottom and left to right
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
                    leftpos = document.defaultView.scrollX;
                    toppos = document.defaultView.scrollY;
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
                overlay.style.zIndex = 10000;
                overlay.style.visibility = 'visible';
                if (isFrame(hint.element)) {
                    overlay.style.border = follow.theme.frame_border;
                    overlay.style.backgroundColor = "transparent";
                } else {
                    overlay.style.border = follow.theme.border;
                    overlay.style.backgroundColor = follow.theme.normal_bg;
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

            this.show = function () {
                this.tick.style.visibility = 'visible';
                this.overlay.style.visibility = 'visible';
                this.visible = true;
            };

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

            // Changes the appearance of the hint to indicate it is focused.
            this.activate = function () {
                this.overlay.style.backgroundColor = follow.theme.focus_bg;
                this.overlay.focus();
                follow.activeHint = this;
            };

            // Changes the appearance of the hint to indicate it is not focused.
            this.deactivate = function () {
                if (isFrame(this.element)) {
                    this.overlay.style.backgroundColor = "transparent";
                } else {
                    this.overlay.style.backgroundColor = follow.theme.normal_bg;
                }
            };

            // Tests if the hint's text matches the given string.
            this.matches = function (str) {
                var text = getText(this.element).toLowerCase();
                return text.indexOf(str) !== -1;
            };
        }

        // Public follow structure.
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
                if (!document.body || !document.activeElement) {
                    return;
                }
                follow.hints = [];
                follow.activeHint = null;
                if (!follow.tickParent) {
                    var tickParent = document.createElement("div");
                    tickParent.id = "luakit_follow_tickParent";
                    document.body.appendChild(tickParent);
                    follow.tickParent = tickParent;
                }
                if (!follow.overlayParent) {
                    var overlayParent = document.createElement("div");
                    overlayParent.id = "luakit_follow_overlayParent";
                    document.body.appendChild(overlayParent);
                    follow.overlayParent = overlayParent;
                }
            },

            // Removes all hints and resets the system to default.
            clear: function() {
                {clear}
                follow.init();
            },

            // Gets all visible elements using the selector and builds
            // hints for them. Returns the number of hints generated.
            // If ignore_frames is set, frames are removed from the
            // list after the matching process.
            match: function (selector, ignore_frames) {
                var elements = getVisibleElements(selector);
                if (ignore_frames) {
                    elements = elements.filter(function (element) {
                        return !isFrame(element);
                    });
                }
                follow.hints = elements.map(function (element) {
                    return new Hint(element);
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

            // Filters the hints according to the given string and ID.
            // Returns the number of Hints that is still visible afterwards and a
            // boolean that indicates whether or not the active element was hidden.
            filter: function (str, id) {
                var strings = str.toLowerCase().split(" ").filter(function (str) {
                    return str !== "";
                });
                var visibleHints = [];
                var reselect = false;
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
                var len = visibleHints.length;
                return "" + len + " " + reselect;
            },

            // Evaluates the given element or the active element, if none is given.
            // If this function returns "continue", the next frame must be tried.
            // Otherwise, it returns "done <val>", where <val> is the return value.
            evaluate: function (element) {
                var hint = element || follow.activeHint;
                if (hint) {
                    // Fix frames which have been selected by the "body" trick
                    if (isFrame(hint.element)) {
                        hint.element = window.frameElement || window;
                    }
                    var ret = follow.evaluator(hint.element);
                    follow.clear();
                    return "done " + ret;
                } else {
                    return "continue";
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
                // we might get a window object if the main frame was focused
                if (!element.tagName) {
                    return false;
                }
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

            focused: function () {
                return follow.activeHint !== null;
            },

            // Selects a visible hint according to the given offset (+1/-1).
            // Returns true if a link was selected and false if the selection
            // should be tried in another frame.
            focus: function (offset) {
                var activeHint = follow.activeHint;
                // deactivate all
                follow.hints.forEach(function (h) { h.deactivate() });
                // get all visible hints
                var visibleHints = follow.hints.filter(function (h) { return h.visible });
                if (visibleHints.length === 0) {
                    follow.activeHint = null;
                    return false;
                } else {
                    // find currently selected hint
                    var currentIdx = null;
                    for (var i = 0; i < visibleHints.length; ++i) {
                        if (visibleHints[i] === activeHint) {
                            currentIdx = i;
                            break;
                        }
                    }
                    if (currentIdx === null) {
                        // if none: select the first/last hint
                        currentIdx = offset < 0 ? visibleHints.length + offset : offset - 1;
                        visibleHints[currentIdx].activate();
                        return true;
                    } else {
                        // calculate new position
                        currentIdx += offset;
                        var focusNextFrame = currentIdx === -1 || currentIdx === visibleHints.length;
                        if (focusNextFrame) {
                            follow.activeHint = null;
                            return false;
                        } else {
                            // norm position to array
                            if (currentIdx < 0) {
                                currentIdx += visibleHints.length;
                            } else if (currentIdx >= visibleHints.length) {
                                currentIdx -= visibleHints.length;
                            }
                            visibleHints[currentIdx].activate();
                            return true;
                        }
                    }
                }
            },
        }
    })();
]=]

local default_theme = {
    focus_bg      = "#00ff00";
    normal_bg     = "#ffff99";
    opacity       = 0.3;
    border        = "1px dotted #000000";
    frame_border  = "2px solid #880000";
    tick_frame_bg = "#880000";
    tick_fg       = "#ffffff";
    tick_bg       = "#000088";
    tick_border   = "2px dashed #000000";
    tick_opacity  = 0.4;
    tick_font     = "11px monospace bold";
    vert_offset   = 0;
    horiz_offset  = -10;
}

-- Merge `theme.follow` table with `follow.default_theme`
local function get_theme()
    return lousy.util.table.join(default_theme, theme.follow or {})
end

--- Selectors for the different modes
-- body selects frames (this is special magic to avoid cross-domain problems)
selectors = {
    followable  = 'a, area, textarea, select, input:not([type=hidden]), button',
    focusable   = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    uri         = 'a, area, body',
    desc        = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    image       = 'img, input[type=image]',
}

--- Evaluators for the different modes
evaluators = {
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
            return element.src || element.href || element.location;
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

--- Table of modes and their selectors & evaulator functions.
modes = {}

-- Build mode table
for _, t in ipairs({
  -- Follow mode,  Selector name,  Evaluator name
    {"follow",     "followable",   "follow"      },
    {"uri",        "uri",          "uri"         },
    {"desc",       "desc",         "desc"        },
    {"focus",      "focusable",    "focus"       },
    {"image",      "image",        "src"         },
}) do
    modes[t[1]] = { selector = t[2], evaluator = t[3] }
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

-- Check if following is possible safely
local function is_ready(w)
    for _, f in ipairs(w:get_current().frames) do
        local ret = w:eval_js("!!(document.activeElement && window.follow)", "(follow.lua)", f)
        if ret ~= "true" then return false end
    end
    return true
end

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

--- Parses the user's input into a match string and an ID.
function parse_input(text)
    return string.match(text, "^(.-)(%d*)$")
end

-- Focus the next element in the correct frame
local function focus(w, offset)
    if not is_ready(w) then return w:set_mode() end
    local function is_focused(f)
        local ret = w:eval_js("follow.focused();", "(follow.lua)", f)
        return ret == "true"
    end
    -- sort frames with currently active one first
    local frames = w:get_current().frames
    if #frames == 0 then return end
    for i=1,#frames,1 do
        if is_focused(frames[1]) then break end
        local f = table.remove(frames, 1)
        table.insert(frames, f)
    end
    -- ask all frames to jump to the next hint until one responds
    for _, f in ipairs(frames) do
        local ret = w:eval_js(string.format("follow.focus(%i);", offset), "(follow.lua)", f)
        if ret == "true" then return end
    end
    -- we get here, if only one frame has visible hints and it reached its limit
    -- in the preciding loop. Thus, we ask it to refocus again
    w:eval_js(string.format("follow.focus(%i);", offset), "(follow.lua)", frames[1])
    w.follow_state.refocus = false
end

-- Add follow mode binds
add_binds("follow", {
    key({},        "Tab",       function (w)
                                    if not is_ready(w) then return w:set_mode() end
                                    focus(w, 1)
                                end ),
    key({"Shift"}, "Tab",       function (w)
                                    if not is_ready(w) then return w:set_mode() end
                                    focus(w, -1)
                                end ),
    key({},        "Return",    function (w)
                                    if not is_ready(w) then return w:set_mode() end
                                    local s = (w.follow_state or {})
                                    for _, f in ipairs(w:get_current().frames) do
                                        local ret = w:eval_js("follow.evaluate();", "(follow.lua)", f)
                                        local done = string.match(ret, "^done")
                                        if done then
                                            local val = string.match(ret, "done (.*)")
                                            local sig = s.func(val, s)
                                            if sig then w:emit_form_root_active_signal(sig) end
                                            return
                                        end
                                    end
                                end),
})

-- Setup follow mode
new_mode("follow", {
    -- Enter follow mode hook
    enter = function (w)
        -- Get following state & options
        if not w.follow_state then w.follow_state = {} end
        local state = w.follow_state
        local mode = modes[state.mode or "follow"]
        -- Get follow mode table
        if not mode then w:set_mode() return error("unknown follow mode") end

        -- Init all frames and gather label data
        local frames = {}
        local sum = 0
        local webkit_frames = w:get_current().frames
        for _, f in ipairs(webkit_frames) do
            -- Load main following js
            local js_blocks = {}
            local subs = {
                clear  = clear_js,
            }
            local js, count = string.gsub(follow_js, "{(%w+)}", subs)
            if count ~= 1 then return error("invalid number of substitutions") end
            table.insert(js_blocks, js);

            -- Make theme js
            for k, v in pairs(get_theme()) do
                if type(v) == "number" then
                    table.insert(js_blocks, string.format("follow.theme.%s = %s;", k, lousy.util.ntos(v)))
                else
                    table.insert(js_blocks, string.format("follow.theme.%s = %q;", k, v))
                end
            end

            -- Load mode specific js
            local evaluator = lousy.util.string.strip(evaluators[mode.evaluator])
            local selector  = selectors[mode.selector],
            table.insert(js_blocks, string.format("follow.evaluator = (%s);", evaluator))
            table.insert(js_blocks, "follow.init();")

            -- Evaluate js code
            local js = table.concat(js_blocks, "\n")
            w:eval_js(js, "(follow.lua)", f)

            local num = tonumber(w:eval_js(string.format("follow.match(%q, %s);", selector, tostring(#webkit_frames == 1)), "(follow.lua)", f))
            table.insert(frames, {num = num, frame = f})
            sum = sum + num
        end
        -- abort if initialization failed
        if not is_ready(w) then return w:set_mode() end

        -- Generate labels
        state.frames = frames
        local labels = make_labels(sum)
        state.labels = lousy.util.table.clone(labels)
        state.current = 1
        for i, l in ipairs(labels) do labels[i] = string.format("%q", l) end

        -- Apply labels
        local last = 0
        for _,t in ipairs(frames) do
            t.labels = {}
            for i=1,t.num,1 do
                t.labels[i] = labels[last+i]
            end
            last = last + t.num
            local array = table.concat(t.labels, ",")
            w:eval_js(string.format("follow.show([%s]);", array), "(follow.lua)", t.frame)
        end

        -- Foucs a hint
        focus(w, 1)

        -- Set prompt & input text
        w:set_prompt(state.prompt and string.format("Follow (%s):", state.prompt) or "Follow:")
        w:set_input("")
    end,

    -- Leave follow mode hook
    leave = function (w)
        if w.eval_js then
            for _,f in ipairs(w:get_current().frames) do
                w:eval_js(clear_js, "(follow.lua)", f)
            end
        end
    end,

    -- Input bar changed hook
    changed = function (w, text)
        if not is_ready(w) then return w:set_mode() end
        local state = w.follow_state or {}
        local filter, id = parse_input(text)
        local active_hints = 0
        local eval_frame
        for _, f in ipairs(w:get_current().frames) do
            local ret = w:eval_js(string.format("follow.filter(%q, %q);", filter, id), "(follow.lua)", f)
            ret = lousy.util.string.split(ret)
            local num = tonumber(ret[1])
            local reselect = (ret[2] == "true")
            if reselect then focus(w, 1) end
            if num == 1 then eval_frame = f end
            active_hints = active_hints + num
        end
        if state.reselect then focus(w, 1) end
        if active_hints == 1 then
            w:set_mode()
            local ret = w:eval_js("follow.evaluate();", "(follow.lua)", eval_frame)
            ret = lousy.util.string.split(ret)
            local sig
            if ret[1] == "done" and state.func then sig = state.func(ret[2], state) end
            if sig then w:emit_form_root_active_signal(sig) end
        elseif active_hints == 0 then
            state.reselect = true
        end
    end,
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
