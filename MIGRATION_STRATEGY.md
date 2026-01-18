# Luakit API Migration Strategy

**Date:** 2026-01-18
**Status:** Planning Phase
**Total Estimated Effort:** 12-16 weeks

## Executive Summary

This document provides a phased migration strategy for moving away from deprecated APIs in luakit. The strategy is ordered by risk and dependency complexity, starting with isolated components and progressing to tightly-coupled core functionality.

**Key Finding:** The migration can be broken into 5 distinct phases, with Phases 1-2 being safe "quick wins" that can be completed in 2-3 weeks with minimal risk.

## Migration Phases Overview

| Phase | Effort | Risk | Components | Timeline |
|-------|--------|------|------------|----------|
| **1: Isolated Features** | 1 week | ⭐ Minimal | 3 web modules | Week 1 |
| **2: Unused Functions** | 1 week | ⭐ Minimal | Deprecated lousy utils | Week 1-2 |
| **3: Utility Migration** | 2 weeks | ⭐⭐ Low | lousy.util functions | Week 2-3 |
| **4: DOM Infrastructure** | 3 weeks | ⭐⭐⭐ Medium | C extension modules | Week 4-6 |
| **5: Core Features** | 6 weeks | ⭐⭐⭐⭐ High | Tightly-coupled web modules | Week 7-12 |

## Dependency Analysis Summary

### Critical Dependencies

```
User Features (follow, formfiller, error pages, etc.)
    ↓
Web Modules (_wm.lua files)
    ↓
DOM Element API (dom_element.c) ← CENTRAL HUB
    ↓
WebKitDOM C API (DEPRECATED)
```

**Critical Insight:** `dom_element.c` is the central hub. Everything flows through it. Cannot be migrated until all consumers are ready.

### Interconnected Cluster

The "Select-Follow-Formfiller" cluster is tightly coupled:

```
select_wm.lua (shared by both)
    ├── follow_wm.lua → follow.lua
    └── formfiller_wm.lua → formfiller.lua
```

These must be migrated together as an atomic unit.

---

## Phase 1: Isolated Features (Week 1)

### Goal
Migrate web modules with minimal dependencies and no downstream consumers.

### Components

#### 1.1 error_page_wm.lua
**Effort:** 4 hours
**Risk:** ⭐ Minimal
**Lines of Code:** ~100

**Current Usage:**
- `element:query()` - Find input elements
- `element:add_event_listener()` - Listen to form submit

**Migration Path:**
Replace with JavaScriptCore evaluation:
```lua
-- Before (WebKitDOM)
local input = doc.body:query("#search_terms")
input:add_event_listener("submit", callback)

-- After (JavaScriptCore)
webview:eval_js([[
    document.querySelector("#search_terms")
        .addEventListener("submit", function(e) {
            webkit.messageHandlers.luakit.postMessage({
                type: "error_page_submit",
                value: e.target.value
            });
        });
]])
```

**Testing:**
1. Visit error page
2. Enter search terms
3. Submit form
4. Verify search works

#### 1.2 image_css_wm.lua
**Effort:** 3 hours
**Risk:** ⭐ Minimal
**Lines of Code:** ~80

**Current Usage:**
- `element.rect` - Get image dimensions
- `element.attr.class` - Check CSS class
- `element.tag_name` - Verify element type

**Migration Path:**
Replace with JavaScript-based property access:
```lua
-- Before (WebKitDOM)
local img = element
local width = img.rect.width
local has_class = img.attr.class:match("scaled")

-- After (JavaScriptCore)
local props = webview:eval_js([[
    (function() {
        var img = document.querySelector("img");
        return {
            width: img.getBoundingClientRect().width,
            hasClass: img.classList.contains("scaled")
        };
    })()
]])
```

**Testing:**
1. Load page with images
2. Test image scaling toggle
3. Verify CSS class changes
4. Check layout updates

#### 1.3 webview_wm.lua
**Effort:** 2 hours
**Risk:** ⭐ Minimal
**Lines of Code:** ~50

**Current Usage:**
- `element.tag_name` - Check if anchor tag
- `element.attr.href` - Get link URL
- `element:click()` - Navigate to link

**Migration Path:**
Very straightforward JavaScript replacement:
```lua
-- Before (WebKitDOM)
if element.tag_name == "A" then
    local href = element.attr.href
    element:click()
end

-- After (JavaScriptCore)
webview:eval_js([[
    var elem = document.querySelector("a");
    if (elem && elem.tagName === "A") {
        elem.click();
    }
]])
```

**Testing:**
1. Click links in chrome pages
2. Verify navigation works
3. Test with different link types

### Phase 1 Success Criteria
- ✅ All 3 modules migrated to JavaScript-based approach
- ✅ All tests passing
- ✅ No regression in functionality
- ✅ Code review completed

### Phase 1 Deliverables
- Updated error_page_wm.lua
- Updated image_css_wm.lua
- Updated webview_wm.lua
- Migration guide document (patterns for JS-based DOM access)
- Test results

---

## Phase 2: Unused Functions (Week 1-2)

### Goal
Remove or deprecate lousy utility functions that are no longer used in core codebase.

### Components

#### 2.1 lousy.util.mkdir()
**Effort:** 1 hour
**Risk:** ⭐ Minimal
**Usage:** NONE in lib/ directory

**Action:**
```lua
-- In lib/lousy/util.lua
_M.mkdir = function(...)
    msg.warn("lousy.util.mkdir() is deprecated. Use lfs.mkdir() or os.execute() instead.")
    -- Provide compatibility for 1-2 releases
    return os.execute(string.format("mkdir -p %q", ...))
end
```

**Testing:**
- Check for external usage in user configs (document migration)
- Verify warning appears
- Test fallback implementation

#### 2.2 lousy.util.eval()
**Effort:** 1 hour
**Risk:** ⭐ Minimal
**Usage:** NONE in lib/ directory

**Action:**
```lua
-- In lib/lousy/util.lua
_M.eval = function(code)
    msg.warn("lousy.util.eval() is deprecated. Use load() directly.")
    local fn, err = load(code)
    if not fn then return nil, err end
    return fn()
end
```

**Testing:**
- Document alternative for users
- Test deprecation warning
- Verify fallback works

#### 2.3 lousy.util.checkfile()
**Effort:** 1 hour
**Risk:** ⭐ Minimal
**Usage:** NONE in lib/ directory

**Action:**
```lua
-- In lib/lousy/util.lua
_M.checkfile = function(path)
    msg.warn("lousy.util.checkfile() is deprecated. Use pcall(loadfile(...)) instead.")
    local fn, err = loadfile(path)
    return fn ~= nil
end
```

### Phase 2 Success Criteria
- ✅ Deprecation warnings added
- ✅ Fallback implementations work
- ✅ Documentation updated
- ✅ Migration guide for users

### Phase 2 Deliverables
- Updated lib/lousy/util.lua with deprecation warnings
- DEPRECATED.md listing deprecated functions
- User migration guide

---

## Phase 3: Utility Migration (Week 2-3)

### Goal
Migrate lousy.util functions that have limited usage to inline implementations or alternatives.

### Components

#### 3.1 lousy.util.table.filter_array()
**Effort:** 4 hours
**Risk:** ⭐⭐ Low
**Usage:** 3 files (formfiller_wm.lua, follow_wm.lua, follow.lua)

**Migration Path:**
Create local helper function in each file:
```lua
-- Replace in each file
-- Before:
local filtered = lousy.util.table.filter_array(array, function(item)
    return item.visible
end)

-- After:
local function filter(array, fn)
    local result = {}
    for i, v in ipairs(array) do
        if fn(v, i) then table.insert(result, v) end
    end
    return result
end

local filtered = filter(array, function(item)
    return item.visible
end)
```

**Testing:**
- Run follow mode tests
- Test form filler element filtering
- Verify no performance regression

#### 3.2 lousy.util.lua_escape()
**Effort:** 2 hours
**Risk:** ⭐ Minimal
**Usage:** 1 file (formfiller_wm.lua)

**Migration Path:**
Inline the function directly in formfiller_wm.lua:
```lua
-- Add to formfiller_wm.lua
local function lua_escape(str)
    return string.format("%q", str):gsub("\\\n", "\\n")
end
```

**Testing:**
- Test form filling with special characters
- Verify quotes, newlines, etc. are escaped properly

### Phase 3 Success Criteria
- ✅ Functions migrated to local implementations
- ✅ No remaining references to deprecated functions
- ✅ All tests passing
- ✅ Performance unchanged

### Phase 3 Deliverables
- Updated formfiller_wm.lua
- Updated follow_wm.lua
- Updated follow.lua
- Performance benchmarks

---

## Phase 4: DOM Infrastructure (Week 4-6)

### Goal
Replace WebKitDOM C API with JavaScript-based alternatives, starting with least complex modules.

**CRITICAL:** This phase requires new infrastructure before migration can begin.

### Prerequisites (Week 4)

#### 4.1 JavaScript Helper Library
Create `lib/dom_helpers.js`:
```javascript
// Injected into web pages to provide DOM manipulation helpers
var luakit_dom = {
    query: function(selector) { return document.querySelector(selector); },
    queryAll: function(selector) { return Array.from(document.querySelectorAll(selector)); },

    createElement: function(tag, attrs, text) {
        var elem = document.createElement(tag);
        if (attrs) {
            for (var k in attrs) elem.setAttribute(k, attrs[k]);
        }
        if (text) elem.textContent = text;
        return elem;
    },

    getRect: function(elem) {
        var rect = elem.getBoundingClientRect();
        return {
            x: rect.x, y: rect.y,
            width: rect.width, height: rect.height,
            top: rect.top, right: rect.right,
            bottom: rect.bottom, left: rect.left
        };
    },

    // Event handling with message passing to Lua
    addEventListener: function(elem, type, handlerId) {
        elem.addEventListener(type, function(e) {
            webkit.messageHandlers.luakit.postMessage({
                type: 'dom_event',
                handlerId: handlerId,
                eventType: type,
                target: { tagName: e.target.tagName, id: e.target.id }
            });
        });
    }
};
```

#### 4.2 Lua/JavaScript Bridge
Create `extension/js_bridge.c`:
```c
// Message handler for JavaScript → Lua communication
void js_message_handler(WebKitUserContentManager *manager,
                       JSCValue *value,
                       gpointer user_data)
{
    // Parse message from JavaScript
    // Route to appropriate Lua callback
    // Handle event dispatching
}
```

### Components

#### 4.3 scroll.c → JavaScript Implementation
**Effort:** 1 week
**Risk:** ⭐⭐⭐ Medium
**Lines of Code:** 122

**Current Functions:**
- Get/set scroll position (scroll X/Y)
- Get window dimensions (inner width/height)
- Get document dimensions (scroll width/height)

**Migration Path:**
Replace C implementation with JavaScript:
```javascript
// extension/scroll.js
window.addEventListener('scroll', function() {
    webkit.messageHandlers.luakit.postMessage({
        type: 'scroll_changed',
        scrollX: window.scrollX,
        scrollY: window.scrollY
    });
});

window.addEventListener('resize', function() {
    webkit.messageHandlers.luakit.postMessage({
        type: 'window_resized',
        innerWidth: window.innerWidth,
        innerHeight: window.innerHeight
    });
});
```

**Testing:**
- Test scroll tracking
- Test window resize detection
- Verify page load scroll position
- Check smooth scrolling

#### 4.4 dom_document.c → JavaScript Wrapper
**Effort:** 1 week
**Risk:** ⭐⭐⭐ Medium
**Lines of Code:** 210

**Current Functions:**
- `create_element()` - Create new DOM elements
- `element_from_point()` - Get element at coordinates
- `get_body()` - Access document body
- Window property access (scroll X/Y, dimensions)

**Migration Path:**
Wrap JavaScript Document API:
```lua
-- New Lua wrapper
document = {}
document.create_element = function(tag, attrs)
    return webview:eval_js(string.format([[
        (function() {
            var elem = document.createElement(%q);
            %s
            return elem;
        })()
    ]], tag, attrs_js_code))
end

document.element_from_point = function(x, y)
    return webview:eval_js(string.format([[
        document.elementFromPoint(%d, %d)
    ]], x, y))
end
```

**Testing:**
- Test element creation
- Test element_from_point with follow mode
- Test document body access
- Verify memory management (no leaks)

### Phase 4 Success Criteria
- ✅ JavaScript helper library created
- ✅ Lua/JavaScript bridge working
- ✅ scroll.c functionality replaced
- ✅ dom_document.c functionality replaced
- ✅ All tests passing
- ✅ No memory leaks

### Phase 4 Deliverables
- lib/dom_helpers.js
- extension/js_bridge.c
- Updated scroll tracking (pure JavaScript)
- Updated document API wrapper
- Performance comparison report
- Memory leak test results

---

## Phase 5: Core Features (Week 7-12)

### Goal
Migrate the tightly-coupled "Select-Follow-Formfiller" cluster to JavaScript-based DOM access.

**CRITICAL:** This phase must be done atomically. All three components migrate together.

### Strategy: Atomic Migration

The three modules are interdependent and must migrate together:

```
select_wm.lua (shared infrastructure)
    ├── follow_wm.lua (depends on select)
    └── formfiller_wm.lua (depends on select)
```

### Components

#### 5.1 dom_element.c → JavaScript Wrapper
**Effort:** 3 weeks
**Risk:** ⭐⭐⭐⭐ High
**Lines of Code:** 991 (largest file)

**Current Functions (60+ methods):**
- Element querying: `query()`, `query_selector_all()`
- Event handling: `add_event_listener()`, `remove_event_listener()`
- Element manipulation: `append()`, `remove()`, `set_inner_html()`
- Navigation: `parent`, `first_child`, `last_child`, `next_sibling`, `prev_sibling`
- Properties: `attributes`, `style`, `rect`, `tag_name`, `text_content`, `inner_text`
- Form interaction: `click()`, `focus()`, `submit()`, `value`
- Visibility: `client_rects`, `offset_*`, `scroll_*`

**Migration Approach:**

1. **Week 7:** Create comprehensive JavaScript wrapper
```javascript
// lib/dom_element.js - Full replacement for dom_element.c
var DOMElement = {
    query: function(selector) {
        return document.querySelector(selector);
    },

    queryAll: function(selector) {
        return Array.from(document.querySelectorAll(selector));
    },

    // ... 60+ methods

    addEventListener: function(elem, type, handlerId) {
        elem.addEventListener(type, function(e) {
            webkit.messageHandlers.luakit.postMessage({
                type: 'dom_event',
                handlerId: handlerId,
                event: serializeEvent(e)
            });
        });
    }
};
```

2. **Week 8:** Create Lua proxy layer
```lua
-- lib/dom_element.lua - Lua API that calls JavaScript
local dom_element = {}

function dom_element.query(selector)
    return webview:eval_js(string.format([[
        DOMElement.query(%q)
    ]], selector))
end

-- ... proxy all 60+ methods
```

3. **Week 9:** Update select_wm.lua to use new API

#### 5.2 select_wm.lua Migration
**Effort:** 1 week
**Risk:** ⭐⭐⭐⭐ High
**Lines of Code:** ~400

**Current Usage:**
- Element visibility checking
- Rect calculation for overlay
- Event listener management
- Parent/sibling traversal

**Migration Path:**
```lua
-- Before (WebKitDOM C API)
local elements = document.body:query_selector_all("a, button")
for _, elem in ipairs(elements) do
    local rect = elem.rect
    if rect.width > 0 and rect.height > 0 then
        -- Create overlay...
    end
end

-- After (JavaScript wrapper)
local elements = dom_element.queryAll("a, button")
for _, elem in ipairs(elements) do
    local rect = dom_element.getRect(elem)
    if rect.width > 0 and rect.height > 0 then
        -- Create overlay...
    end
end
```

**Testing:**
- Test element selection
- Test overlay rendering
- Test visibility calculations
- Test event handling

#### 5.3 follow_wm.lua Migration
**Effort:** 1 week
**Risk:** ⭐⭐⭐⭐ High
**Lines of Code:** ~300

**Dependencies:**
- Requires select_wm.lua (migrated in 5.2)
- Requires dom_element API (migrated in 5.1)

**Migration Path:**
Update to use new JavaScript-based select_wm.lua

**Testing:**
- Test link following (f key)
- Test different hint modes
- Test tab/window opening
- Test click/focus behavior

#### 5.4 formfiller_wm.lua Migration
**Effort:** 1 week
**Risk:** ⭐⭐⭐⭐ High
**Lines of Code:** ~350

**Dependencies:**
- Requires select_wm.lua (migrated in 5.2)
- Requires dom_element API (migrated in 5.1)

**Migration Path:**
Update to use new JavaScript-based APIs

**Testing:**
- Test form detection
- Test form filling
- Test input element selection
- Test form submission

### Phase 5 Success Criteria
- ✅ All 3 web modules migrated atomically
- ✅ JavaScript wrapper complete (60+ methods)
- ✅ All tests passing for follow mode
- ✅ All tests passing for form filler
- ✅ No regressions in functionality
- ✅ Performance within 10% of original

### Phase 5 Deliverables
- lib/dom_element.js (comprehensive JavaScript wrapper)
- lib/dom_element.lua (Lua proxy layer)
- Updated select_wm.lua
- Updated follow_wm.lua
- Updated formfiller_wm.lua
- Comprehensive test suite
- Performance benchmarks
- Migration completion report

---

## Testing Strategy

### Per-Phase Testing

Each phase must pass all tests before proceeding to the next phase.

#### Phase 1-2 Testing
- **Unit tests:** Test migrated modules in isolation
- **Integration tests:** Test with other modules
- **Manual testing:** Basic functionality verification
- **Time estimate:** 1 day per phase

#### Phase 3 Testing
- **Unit tests:** Test utility function replacements
- **Integration tests:** Test all consumers
- **Performance tests:** Benchmark before/after
- **Time estimate:** 2 days

#### Phase 4 Testing
- **Unit tests:** Test JavaScript helpers
- **Integration tests:** Test Lua/JS bridge
- **Memory tests:** Check for leaks
- **Performance tests:** Benchmark scroll tracking
- **Time estimate:** 3 days

#### Phase 5 Testing
- **Unit tests:** Test all 60+ DOM methods
- **Integration tests:** Full follow/formfiller testing
- **Regression tests:** Compare with original behavior
- **Performance tests:** Benchmark all operations
- **Memory tests:** Extended leak testing
- **User acceptance testing:** Real-world usage
- **Time estimate:** 5 days

### Continuous Testing

- Run full test suite after each commit
- Automated CI testing for each phase
- Performance benchmarking dashboard
- Memory profiling for long-running tests

---

## Risk Mitigation

### Phase 1-3 Risks: LOW
**Mitigation:** Easy rollback, isolated changes

### Phase 4 Risks: MEDIUM
**Potential Issues:**
- JavaScript helper library bugs
- Lua/JavaScript bridge communication failures
- Memory leaks in JS→Lua object passing
- Performance degradation

**Mitigation:**
- Extensive unit testing of bridge layer
- Memory profiling with valgrind
- Performance benchmarking before/after
- Feature flags for gradual rollout

### Phase 5 Risks: HIGH
**Potential Issues:**
- Breaking core user features (follow, formfiller)
- Complex event handling edge cases
- Memory leaks with event listeners
- Performance regression with JavaScript evaluation
- Race conditions in async JavaScript execution

**Mitigation:**
- Atomic migration (all 3 modules together)
- Extensive regression testing
- User beta testing period
- Rollback plan (keep old C code temporarily)
- Feature flag for new vs. old implementation
- Extended testing period (2-3 weeks)

---

## Rollback Plan

### Phase 1-3: Immediate Rollback
- Simple git revert
- Minimal user impact
- Rollback time: 1 hour

### Phase 4: Conditional Compilation
```makefile
# Add to Makefile
ifdef USE_OLD_SCROLL
    CFLAGS += -DUSE_OLD_SCROLL
endif
```

Keep old C code behind preprocessor directive for 1-2 releases.

### Phase 5: Feature Flag
```lua
-- lib/globals.lua
globals.use_js_dom = false  -- Default: old implementation

-- In select_wm.lua
if globals.use_js_dom then
    -- New JavaScript implementation
else
    -- Old WebKitDOM implementation (deprecated)
end
```

Allow users to switch between implementations for 1-2 releases.

---

## Success Metrics

### Code Quality
- ✅ Zero deprecation warnings
- ✅ All tests passing
- ✅ Code coverage maintained or improved
- ✅ Luacheck passes

### Performance
- ✅ Follow mode performance within 10% of original
- ✅ Formfiller performance within 10% of original
- ✅ Page load time unchanged
- ✅ Memory usage stable (no leaks)

### User Experience
- ✅ No regressions in functionality
- ✅ All keybindings work
- ✅ User configs continue to work
- ✅ Documentation updated

### Maintainability
- ✅ Code easier to understand
- ✅ Better separation of concerns
- ✅ Modern APIs used throughout
- ✅ Technical debt reduced

---

## Timeline Summary

| Week | Phase | Components | Risk | Deliverables |
|------|-------|------------|------|--------------|
| 1 | Phase 1 | Isolated web modules | ⭐ | 3 migrated modules |
| 1-2 | Phase 2 | Deprecated functions | ⭐ | Deprecation warnings |
| 2-3 | Phase 3 | Utility functions | ⭐⭐ | Inline implementations |
| 4 | Phase 4 Prep | JS infrastructure | ⭐⭐⭐ | Helper library + bridge |
| 4-5 | Phase 4 | scroll.c | ⭐⭐⭐ | JS scroll tracking |
| 5-6 | Phase 4 | dom_document.c | ⭐⭐⭐ | JS document wrapper |
| 7 | Phase 5 Prep | dom_element.js | ⭐⭐⭐⭐ | Comprehensive wrapper |
| 8 | Phase 5 Prep | dom_element.lua | ⭐⭐⭐⭐ | Lua proxy layer |
| 9 | Phase 5 | select_wm.lua | ⭐⭐⭐⭐ | Migrated select module |
| 10 | Phase 5 | follow_wm.lua | ⭐⭐⭐⭐ | Migrated follow module |
| 11 | Phase 5 | formfiller_wm.lua | ⭐⭐⭐⭐ | Migrated formfiller |
| 12 | Testing | Integration testing | ⭐⭐⭐⭐ | Full test suite passing |

**Total Time:** 12 weeks (optimistic) to 16 weeks (realistic with buffer)

---

## Post-Migration Cleanup

After all phases complete:

1. **Remove Old Code** (Week 13-14)
   - Delete old WebKitDOM C code
   - Remove feature flags
   - Clean up compatibility layers

2. **Documentation** (Week 14-15)
   - Update developer documentation
   - Create user migration guide
   - Update API documentation
   - Write blog post about migration

3. **Release** (Week 15-16)
   - Beta release with new implementation
   - Gather user feedback
   - Fix reported issues
   - Stable release

---

## Resources Required

### Developer Time
- **1 senior developer:** Full-time for 12-16 weeks
- **1 reviewer:** Part-time for code reviews
- **Testers:** Community testing during beta

### Infrastructure
- CI/CD pipeline for automated testing
- Performance benchmarking environment
- Memory profiling tools (valgrind, heaptrack)
- Test coverage tools

### Documentation
- Migration guide for users
- API documentation updates
- Developer documentation
- Release notes

---

## Conclusion

This migration strategy provides a clear, phased approach to moving away from deprecated WebKitDOM APIs. By starting with isolated, low-risk components and progressing to tightly-coupled core functionality, we minimize risk while making steady progress.

**Key Success Factors:**
1. ✅ Phased approach with clear boundaries
2. ✅ Extensive testing at each phase
3. ✅ Atomic migration of interdependent components
4. ✅ Rollback plans for high-risk phases
5. ✅ Performance monitoring throughout

**Recommendation:** Begin with Phases 1-2 immediately (low risk, quick wins), then evaluate resources and timeline for the more complex later phases.

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**Next Review:** After Phase 2 completion
