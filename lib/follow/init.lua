-------------------------------------------------------
-- Vimperator-like link following script for luakit  --
-- © 2010 Fabian Streitel <karottenreibe@gmail.com>  --
-- © 2010 Mason Larobina  <mason.larobina@gmail.com> --
-------------------------------------------------------

local ipairs, pairs = ipairs, pairs
local table, string = table, string
local tonumber, tostring = tonumber, tostring
local type, unpack = type, unpack
local assert = assert

local lousy = require "lousy"
local window = window
local webview = webview
local downloads = require "downloads"
local add_binds, new_mode = add_binds, new_mode
local theme = theme
local capi = { luakit = luakit, timer = timer }

require "follow.modes"
require "follow.binds"
require "follow.styles"

--- Provides link following.
module("follow")

--- The follow module.
-- @field ignore_delay Determines how long input from the user should be ignored
--  after a successful follow.
--  <br> This helps avoid accidentially triggering normal mode binds after a
--  follow.
--  <br> The duration is given in milliseconds.
-- @filed style The style to use for following.
--  <br> See <code>follow.styles</code> for details.
-- @field selectors A hash of <code>mode = selector</code>.
--  <br> <code>mode</code> is the name of a follow mode.
--  <br> <code>selector</code> is a CSS selector that indicates all elements
--  that can be followed.
-- @field evaluators A hash of <code>mode = evaluator</code>
--  <br> <code>mode</code> is the name of a follow mode.
--  <br> <code>evaluator</code> is a javascript function that gets the element
--  that was selected for following and performs the following. Optionally, it
--  may return <code>"form-active"</code> or <code>"root-active"</code>.
-- @type table
-- @name follow
ignore_delay = 250
style = styles.sort(styles.reverse(styles.numbers_and_labels()))

-- Clears all follow stuff from the page.
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
            return a.getClientRects()[0].left - b.getClientRects()[0].left;
        });
        elements.sort(function (a,b) {
            return a.getClientRects()[0].top - b.getClientRects()[0].top;
        });
        return elements;
    }

    function createElement(tag) {
        var element = document.createElement(tag);
        // This fails on some sites, need to use xhtml namespace there
        if (!element.style) {
            var ns = document.getElementsByTagName('html')[0].getAttribute('xmlns') || "http://www.w3.org/1999/xhtml"
            element = document.createElementNS(ns, tag);
        }
        return element;
    }

    // Hint class. Wraps data and functions related to hint manipulation.
    function Hint(element) {
        this.element = element;
        this.rect = element.getBoundingClientRect();
        this.rect0 = element.getClientRects()[0];

        // Hint creation helper functions.
        function createSpan(hint, h, v) {
            var span = createElement("span");
            var leftpos, toppos;
            if (isFrame(hint.element)) {
                leftpos = document.defaultView.scrollX;
                toppos = document.defaultView.scrollY;
            } else {
                leftpos = Math.max((hint.rect0.left + document.defaultView.scrollX), document.defaultView.scrollX) + h;
                toppos  = Math.max((hint.rect0.top  + document.defaultView.scrollY), document.defaultView.scrollY) + v;
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
            var tick = createSpan(hint, follow.theme.horiz_offset, follow.theme.vert_offset - hint.rect0.height/2);
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
            tick.addEventListener('click', function () { click(tick.element); }, false );
            return tick;
        }

        function createOverlay(hint) {
            var overlay = createSpan(hint, 0, 0);
            overlay.style.width  = (hint.rect.left + hint.rect.width   - hint.rect0.left) + "px";
            overlay.style.height = (hint.rect0.top + hint.rect0.height - hint.rect.top)   + "px";
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
            overlay.addEventListener('click', function () { click(hint.element); }, false );
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
            if (!document.body || !/interactive|loaded|complete/.test(document.readyState)) {
                return;
            }
            follow.hints = [];
            follow.activeHint = null;
            if (!follow.tickParent) {
                var tickParent = createElement("div");
                tickParent.id = "luakit_follow_tickParent";
                document.body.appendChild(tickParent);
                follow.tickParent = tickParent;
            }
            if (!follow.overlayParent) {
                var overlayParent = createElement("div");
                overlayParent.id = "luakit_follow_overlayParent";
                document.body.appendChild(overlayParent);
                follow.overlayParent = overlayParent;
            }
        },

        // Removes all hints and resets the system to default.
        clear: function () {
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
            if (document.activeElement) {
                document.activeElement.blur();
            }
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

-- Insert clear_js function into main following JavaScript
follow_js = string.gsub(follow_js, "{clear}", clear_js)

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

function mk_theme_js()
    -- Merge `theme.follow` table with `follow.default_theme`
    local theme = lousy.util.table.join(default_theme, theme.follow or {})
    local lines, ntos = {}, lousy.util.ntos
    for k, v in pairs(theme) do
        if type(v) == "number" then
            table.insert(lines,
                string.format("follow.theme.%s = %s;", k, ntos(v)))
        else
            table.insert(lines,
                string.format("follow.theme.%s = %q;", k, v))
        end
    end
    return table.concat(lines, "\n")
end

-- Add webview methods
webview.methods.start_follow = function (view, w, mode, prompt, func, count)
    assert(type(mode) == "table", "invalid mode table")
    assert(type(func) == "function", "invalid callback function")
    w.follow_state = { mode = mode, prompt = prompt, func = func, count = count }
    w:set_mode("follow")
end

-- Check if following is possible safely
local function is_ready(w)
    for _, f in ipairs(w.view.frames) do
        local ret = w:eval_js("!!(document.body && /interactive|loaded|complete/.test(document.readyState) && window.follow)", "(follow.lua)", f)
        if ret ~= "true" then return false end
    end
    return true
end

-- Focus the next element in the correct frame
local function focus(w, offset)
    if not is_ready(w) then return w:set_mode() end
    local function is_focused(f)
        return (w:eval_js("follow.focused();", "(follow.lua)", f) == "true")
    end
    -- sort frames with currently active one first
    local frames = w.view.frames
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

-- Simple key-eating mode to prevent any follow keys from accidentally
-- triggering unexpected behaviour.
local any = lousy.bind.any
new_mode("follow_ignore", {
    any(function () end),

    enter = function (w)
        w:set_input()
    end
})

-- Ignores any keypresses for ignore_delay milliseconds, then calls fun.
local function ignore_keys(w, fun)
    if ignore_delay > 0 then
        if sig == "form-active" then
            w:emit_form_root_active_signal(sig)
        else
            local ignore_timer = capi.timer{interval=ignore_delay}
            ignore_timer:add_signal("timeout", function (t)
                t:stop()
                fun()
            end)
            w:set_mode("follow_ignore")
            ignore_timer:start()
        end
    else
    end
end

-- Accepts the follow after pressing enter or narrowing down the search to a
-- single item.
-- Does nothing if the window is not ready for following.
local function accept_follow(w, frame)
    if not is_ready(w) then return w:set_mode() end
    local s = (w.follow_state or {})
    local val
    if frame then
        local ret = w:eval_js("follow.evaluate();", "(follow.lua)", frame)
        local done = string.match(ret, "^done")
        if done then
            val = string.match(ret, "done (.*)")
        end
    else
        for _, f in ipairs(w.view.frames) do
            local ret = w:eval_js("follow.evaluate();", "(follow.lua)", f)
            local done = string.match(ret, "^done")
            if done then
                frame = f
                val = string.match(ret, "done (.*)")
                break
            end
        end
    end
    if val then
        ignore_keys(w, function ()
            local sig = s.func(val, s)
            if sig then w:emit_form_root_active_signal(sig) end
        end)
    else
        w:set_mode()
        w:error("Following failed")
    end
end

-- Add follow mode binds
local key = lousy.bind.key
add_binds("follow", {
    -- Cycle through remaining follow tags
    key({}, "Tab", function (w)
        if not is_ready(w) then return w:set_mode() end
        focus(w, 1)
    end),

    -- Reverse-cycle through remaining follow tags
    key({"Shift"}, "Tab", function (w)
        if not is_ready(w) then return w:set_mode() end
        focus(w, -1)
    end),

    -- Evaluate selected follow tag
    key({}, "Return", function (w)
        accept_follow(w)
    end),
})

-- Setup follow mode
new_mode("follow", {
    -- Enter follow mode hook
    enter = function (w)
        -- Get following state & options
        if not w.follow_state then w.follow_state = {} end
        local state = w.follow_state
        if not state.mode or type(state.mode) ~= "table" then
            w:set_mode()
            w:error("invalid follow mode table")
        end

        -- Init all frames and gather label data
        local frames = {}
        local theme_js = mk_theme_js()

        local sum = 0
        local webkit_frames = w.view.frames
        local ignore_frames = tostring(#webkit_frames == 1)
        local m = state.mode

        local init_js = table.concat({
            follow_js, theme_js,
            string.format("follow.evaluator = (%s);", m.evaluator),
            "follow.init();",
        }, "\n")

        local match_js = string.format("follow.match(%q, %s);",
            m.selector, ignore_frames)

        for _, f in ipairs(webkit_frames) do
            -- Init follow js in frame
            w:eval_js(init_js, "(follow.lua)", f)
            -- Get number of matches in the frame
            local num = tonumber(w:eval_js(match_js, "(follow.lua)", f))
            table.insert(frames, {num = num, frame = f})
            sum = sum + num
        end

        -- abort if initialization failed
        if not is_ready(w) then return w:set_mode() end

        -- Generate labels
        state.frames = frames
        local labels = style.make_labels(sum)
        state.current = 1
        for i, l in ipairs(labels) do labels[i] = string.format("%q", l) end

        -- Apply labels
        local last = 0
        for _,t in ipairs(frames) do
            t.labels = table.concat(labels, ",", last + 1, last + t.num)
            last = last + t.num
            local show_js = string.format("follow.show([%s]);", t.labels)
            w:eval_js(show_js, "(follow.lua)", t.frame)
        end

        -- Foucs a hint
        focus(w, 1)

        -- Set prompt & input text
        local p = state.prompt
        w:set_prompt((p and string.format("Follow (%s):", p)) or "Follow:")
        w:set_input("")
    end,

    -- Leave follow mode hook
    leave = function (w)
        if w.eval_js then
            for _,f in ipairs(w.view.frames) do
                w:eval_js(clear_js, "(follow.lua)", f)
            end
        end
    end,

    -- Input bar changed hook
    changed = function (w, text)
        if not is_ready(w) then return w:set_mode() end
        local state = w.follow_state or {}
        local filter, id = style.parse_input(text)
        local active_hints = 0
        local eval_frame
        local split = lousy.util.string.split
        local filter_js = string.format("follow.filter(%q, %q);", filter, id)
        for _, f in ipairs(w.view.frames) do
            local ret = split(w:eval_js(filter_js, "(follow.lua)", f))
            if ret[2] == "true" then focus(w, 1) end -- Reselect active hint
            local num = tonumber(ret[1])
            if num == 1 then eval_frame = f end
            active_hints = active_hints + num
        end
        if state.reselect then focus(w, 1) end
        if active_hints == 1 then
            accept_follow(w, eval_frame)
        elseif active_hints == 0 then
            state.reselect = true
        end
    end,
})

-- vim: et:sw=4:ts=8:sts=4:tw=80
