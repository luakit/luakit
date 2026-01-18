# JavaScript→Lua Callback Pattern

**Created:** 2026-01-18
**Status:** ✅ Implemented and Working

## Overview

This document describes the new JavaScript→Lua callback infrastructure that enables JavaScript code in web pages to call Lua functions in the WebKit extension process. This is a critical piece of infrastructure for migrating away from the deprecated WebKitDOM API.

## The Problem We Solved

Previously, luakit used WebKitDOM C API to manipulate the DOM and attach event listeners:

```lua
-- OLD WAY (using deprecated WebKitDOM API)
local doc = page.document
for i, elem in ipairs(doc.body:query("input[type=button]")) do
    elem:add_event_listener("click", true, function (_)
        -- Lua callback executed directly
        ui:emit_signal("click", page.id, i)
    end)
end
```

**Problems:**
- Uses deprecated `WebKitDOM` C API
- Will break when WebKit removes the API
- 215 deprecation warnings when compiling

## The Solution

We created a new `page:register_js_callback()` function that:
1. Registers a Lua function to be callable from JavaScript
2. Injects a JavaScript function with the same name into the page's JavaScript context
3. When JavaScript calls the function, it routes to the Lua callback
4. Converts JavaScript arguments to Lua values automatically

## New Pattern Usage

### Basic Example

```lua
-- Register a Lua callback that JavaScript can invoke
page:register_js_callback("my_callback", function(arg1, arg2)
    print("Called from JavaScript with:", arg1, arg2)
end)

-- Now JavaScript can call it
page:eval_js([[
    my_callback("hello", 42);
]])
```

### Real-World Example: error_page_wm.lua Migration

**Before (WebKitDOM):**
```lua
ui:add_signal("listen", function(_, page)
    local doc = page.document
    for i, elem in ipairs(doc.body:query("input[type=button]")) do
        elem:add_event_listener("click", true, function (_)
            ui:emit_signal("click", page.id, i)
        end)
    end
end)
```

**After (JavaScript + Callbacks):**
```lua
ui:add_signal("listen", function(_, page)
    -- Register Lua callback
    page:register_js_callback("luakit_error_page_button_click", function(button_index)
        ui:emit_signal("click", page.id, button_index)
    end)

    -- Use standard JavaScript DOM API
    page:eval_js([[
        (function() {
            var buttons = document.querySelectorAll('input[type=button]');
            buttons.forEach(function(btn, index) {
                btn.addEventListener('click', function() {
                    luakit_error_page_button_click(index + 1); // Call Lua!
                });
            });
        })();
    ]])
end)
```

**Benefits:**
- ✅ No deprecated WebKitDOM API
- ✅ Uses standard JavaScript DOM APIs
- ✅ More maintainable (JavaScript is more familiar than C DOM API)
- ✅ Better separation of concerns
- ✅ Future-proof

## API Reference

### `page:register_js_callback(name, callback)`

Registers a Lua function to be callable from JavaScript running in the page.

**Parameters:**
- `name` (string): The name of the JavaScript function to create
- `callback` (function): The Lua function to call when JavaScript invokes the callback

**Returns:** Nothing

**JavaScript Side:**
After registration, JavaScript can call the function by name. Arguments are automatically converted from JavaScript to Lua types.

**Supported Argument Types:**
- Numbers (converted to Lua numbers)
- Strings (converted to Lua strings)
- Booleans (converted to Lua booleans)
- null/undefined (converted to Lua nil)
- Objects and Arrays (converted to Lua tables)

**Example:**
```lua
-- Lua side: Register callback
page:register_js_callback("process_data", function(user, age, active)
    print(string.format("User %s is %d years old, active=%s",
                        user, age, tostring(active)))
end)

-- JavaScript side: Call it
page:eval_js([[
    process_data("Alice", 30, true);
    // Output: User Alice is 30 years old, active=true
]])
```

### Callback Lifecycle

**Registration:** When `register_js_callback()` is called:
1. Lua function is stored with a reference in the page's callback hash table
2. JavaScript function is injected into the page's script world
3. JavaScript function is set up to route calls to the Lua callback

**Invocation:** When JavaScript calls the function:
1. C callback handler is invoked
2. JavaScript arguments are converted to Lua values
3. Lua callback function is called with the converted arguments
4. Lua callback executes (return values are not supported)

**Cleanup:** When the page is destroyed:
1. Callback hash table is destroyed
2. All Lua function references are unreferenced
3. JavaScript functions are automatically cleaned up by WebKit

**Re-registration:** If you call `register_js_callback()` with the same name twice:
- Old callback is automatically unreferenced
- New callback replaces it
- JavaScript code can continue using the same function name

## Implementation Details

### C Code Structure

**Files Modified:**
- `extension/clib/page.h` - Added `js_callbacks` hash table to page_t struct
- `extension/clib/page.c` - Implemented registration and callback handling
- `common/tokenize.list` - Added `register_js_callback` token

**Key Functions:**
- `luaH_page_register_js_callback()` - Lua API function
- `js_callback_handler()` - C callback invoked by JavaScript
- `js_callback_data_free()` - Cleanup function
- `lua_ref_destroy()` - GDestroyNotify wrapper for hash table

**Data Structures:**
```c
typedef struct {
    page_t *page;
    gchar *callback_name;
} js_callback_data_t;

typedef struct _page_t {
    // ... other fields ...
    GHashTable *js_callbacks;  // name -> lua_ref mapping
} page_t;
```

### Memory Management

**Lua Function References:**
- Stored using `luaH_object_ref()` when registered
- Retrieved from hash table when JavaScript calls
- Unreferenced when replaced or page destroyed

**Callback Data:**
- Allocated with `g_slice_new()` when registering
- Freed automatically by GLib when JavaScript function is destroyed
- Callback name is duplicated with `g_strdup()` and freed with `g_free()`

**Hash Table:**
- Created lazily on first callback registration
- Keys: strings (callback names), freed with `g_free()`
- Values: Lua references, freed with `lua_ref_destroy()`
- Destroyed when page is destroyed

## Performance Considerations

**Registration Overhead:**
- One-time cost per callback
- Minimal: hash table insert + JavaScript function creation
- Negligible compared to WebKitDOM object overhead

**Invocation Overhead:**
- JavaScript→C→Lua call chain
- Argument conversion from JSC types to Lua types
- Comparable to WebKitDOM event listener overhead
- No async overhead (synchronous callbacks)

**Memory Overhead:**
- One hash table per page (lazy allocation)
- One reference per registered callback
- One js_callback_data_t struct per callback
- Total: ~100-200 bytes per callback

## Migration Checklist

When migrating a web module from WebKitDOM to JavaScript callbacks:

- [ ] Identify all DOM element queries
  - Replace `doc.body:query()` with JavaScript `document.querySelectorAll()`

- [ ] Identify all event listeners
  - Replace `elem:add_event_listener()` with JavaScript `addEventListener()`

- [ ] Design callback interface
  - Decide what data needs to flow from JavaScript to Lua
  - Choose meaningful callback names (use module prefix)

- [ ] Register callbacks
  - Call `page:register_js_callback()` for each callback
  - Implement Lua callback functions

- [ ] Inject JavaScript
  - Use `page:eval_js()` to run JavaScript DOM manipulation
  - Call registered callbacks from JavaScript event handlers

- [ ] Test thoroughly
  - Verify events trigger correctly
  - Check argument conversion
  - Test page navigation and cleanup

## Common Patterns

### Pattern 1: Simple Button Click

```lua
page:register_js_callback("button_clicked", function(button_id)
    handle_button_click(button_id)
end)

page:eval_js([[
    document.querySelectorAll('button').forEach(function(btn) {
        btn.addEventListener('click', function() {
            button_clicked(btn.id);
        });
    });
]])
```

### Pattern 2: Form Submission

```lua
page:register_js_callback("form_submitted", function(form_data)
    process_form(form_data)
end)

page:eval_js([[
    document.querySelector('form').addEventListener('submit', function(e) {
        e.preventDefault();
        var data = {
            username: this.username.value,
            email: this.email.value
        };
        form_submitted(data);
    });
]])
```

### Pattern 3: Element Selection

```lua
page:register_js_callback("element_selected", function(element_info)
    follow_link(element_info.href, element_info.target)
end)

page:eval_js([[
    document.querySelectorAll('a').forEach(function(link, index) {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            element_selected({
                href: this.href,
                target: this.target,
                index: index
            });
        });
    });
]])
```

### Pattern 4: Scroll Tracking

```lua
page:register_js_callback("scroll_changed", function(scroll_x, scroll_y)
    update_scroll_position(scroll_x, scroll_y)
end)

page:eval_js([[
    window.addEventListener('scroll', function() {
        scroll_changed(window.scrollX, window.scrollY);
    });
]])
```

## Comparison: Before vs. After

| Aspect | WebKitDOM (Old) | JavaScript Callbacks (New) |
|--------|-----------------|----------------------------|
| **API Status** | Deprecated | Standard |
| **Compiler Warnings** | 215 warnings | 0 warnings |
| **Future Proof** | ❌ Will be removed | ✅ Standard APIs |
| **Maintainability** | ⭐⭐ Complex C API | ⭐⭐⭐⭐ Familiar JavaScript |
| **Performance** | Fast (direct C) | Fast (JIT-compiled JS) |
| **Flexibility** | Limited to DOM API | Full JavaScript capabilities |
| **Error Handling** | C-level errors | JavaScript try/catch |
| **Debugging** | Difficult | Browser DevTools |

## Troubleshooting

### Callback Not Being Called

**Check:**
1. Is the callback registered before the JavaScript runs?
2. Is the JavaScript code actually executing? (Add `console.log()`)
3. Is the callback name spelled correctly in both Lua and JavaScript?
4. Are there JavaScript errors? (Check browser console)

### Arguments Not Converting Correctly

**Check:**
1. Are you passing supported JavaScript types?
2. Complex objects may not convert as expected
3. Use simple types: numbers, strings, booleans
4. For complex data, serialize to JSON string and parse in Lua

### Memory Leaks

**Check:**
1. Are callbacks being unregistered when no longer needed?
2. Is the page being properly destroyed?
3. Are Lua function references being held elsewhere?

### Page Navigation Issues

**Remember:**
- Callbacks are per-page instance
- When navigating to a new page, callbacks are cleared
- Re-register callbacks on `document-loaded` if needed

## Future Improvements

**Potential Enhancements:**
1. **Return Values:** Support callbacks that return values to JavaScript
2. **Async Callbacks:** Support Promise-based async patterns
3. **Bulk Registration:** Register multiple callbacks at once
4. **Callback Introspection:** Query what callbacks are registered
5. **Performance Metrics:** Track callback invocation statistics

## Related Documentation

- **MIGRATION_STRATEGY.md** - Overall migration plan for luakit
- **COMPILATION_REPORT.md** - Analysis of deprecation warnings
- **AUDIT_SUMMARY.md** - Complete audit of codebase
- **WebKit JavaScriptCore Documentation** - JSC API reference

## Examples in Codebase

**Migrated Modules:**
- ✅ `lib/error_page_wm.lua` - Error page button handling

**Pending Migration:**
- ⏳ `lib/image_css_wm.lua` - Image property access
- ⏳ `lib/webview_wm.lua` - Link click handling
- ⏳ `lib/select_wm.lua` - Element selection (complex)
- ⏳ `lib/follow_wm.lua` - Link hints (complex)
- ⏳ `lib/formfiller_wm.lua` - Form auto-fill (complex)

## Credits

- **Implementation:** Claude (2026-01-18)
- **Based On:** Existing luaJS infrastructure in extension/luajs.c
- **Inspired By:** WebKit JavaScriptCore callback patterns

---

**Last Updated:** 2026-01-18
**Status:** Production Ready
**Version:** 1.0
