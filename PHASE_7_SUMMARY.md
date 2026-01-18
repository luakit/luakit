# Phase 7: Eliminate webkit_web_page_get_main_frame() Deprecation Warnings

## Summary

Successfully eliminated all 9 deprecation warnings related to `webkit_web_page_get_main_frame()` by implementing a JavaScript context caching system. This phase addresses the remaining low-hanging fruit in deprecation warning reduction after the WebKitDOM migration (Phases 4-6).

## Deprecation Warning Reduction

**Before Phase 7:** 81 total deprecation warnings
- 9 webkit_web_page_get_main_frame() warnings
- 72 WebKitDOM warnings (from Phases 5-6)

**After Phase 7:** 72 total deprecation warnings
- 0 webkit_web_page_get_main_frame() warnings ✅
- 72 WebKitDOM warnings (unchanged - architectural boundary)

**Warnings Eliminated:** 9 (100% of webkit_web_page_get_main_frame warnings)

## Technical Approach

### Why webkit_web_page_get_main_frame() Was Deprecated

WebKit deprecated `webkit_web_page_get_main_frame()` as part of Site Isolation architecture work. The function became problematic because:
- Site Isolation makes frame access more complex
- No direct replacement API is available yet
- Recommended approach: cache contexts when legitimately available

### Solution: JavaScript Context Cache

Implemented a caching layer that stores JSCContext per page_id:

1. **Cache Infrastructure** (extension/luajs.c)
   - GHashTable mapping page_id → JSCContext
   - Proper reference counting (g_object_ref/unref)
   - Automatic cleanup on page destruction

2. **Cache Population** (window-object-cleared event)
   - Triggered when main frame JavaScript context becomes available
   - Legitimate access to frame at this point
   - Cache stores context for later use

3. **Cache Consumers** (7 files updated)
   - Replaced all get_main_frame() calls with js_context_cache_get()
   - Proper error handling when context unavailable
   - Unref returned contexts after use

## Files Modified

### Core Infrastructure
- **extension/luajs.c** - Implemented cache (init/set/get/remove)
- **extension/luajs.h** - Exported js_context_cache_get()

### Cache Consumers
- **extension/ipc.c** - IPC JavaScript evaluation (ipc_recv_eval_js)
- **extension/scroll.c** - Scroll event handlers and web_scroll_to
- **extension/clib/dom_document.c** - Document window property access
- **extension/clib/dom_element.c** - Element JavaScript operations
- **extension/clib/page.c** - Page JavaScript evaluation and function registration

## Key Implementation Details

### Cache Lifecycle

```c
/* Initialize on startup */
js_context_cache_init()
  → Creates GHashTable with g_object_unref as destroy function

/* Populate on window-object-cleared */
window_object_cleared_cb()
  → Get JSCContext from frame (legitimate access point)
  → js_context_cache_set(page_id, ctx)
  → g_object_ref(ctx) for cache ownership

/* Access when needed */
JSCContext *ctx = js_context_cache_get(page_id)
  → Returns new reference (caller must unref)
  → Returns NULL if context not available

/* Cleanup on page destruction */
page_created_cb() → Connect to destroy signal
  → js_context_cache_remove(page_id)
  → GHashTable calls g_object_unref automatically
```

### Reference Counting Pattern

Every cache consumer follows this pattern:
```c
JSCContext *ctx = js_context_cache_get(page_id);
if (!ctx)
    return;  /* Context not available */

/* Use context for JavaScript operations */
// ... jsc_context_evaluate() etc.

g_object_unref(ctx);  /* Release reference */
```

## Build Results

```bash
Before: 81 deprecation warnings
After:  72 deprecation warnings
Change: -9 warnings (webkit_web_page_get_main_frame eliminated)

Build status: SUCCESS
Binary size: 221K (luakit.so)
Compilation errors: 0
```

## Remaining Deprecation Warnings

The 72 remaining WebKitDOM warnings are from Phases 5-6 work and exist at the "architectural boundary":

- Infrastructure code (selector generation, type checking)
- Event handling system
- Navigation properties (parent, children, siblings)
- Query methods (querySelector, querySelectorAll)

These would require 40-80 hours of architectural refactoring to eliminate. See REMAINING_DEPRECATIONS_ANALYSIS.md for details.

## Architectural Improvements

Beyond warning reduction, this phase improved the codebase by:

1. **Eliminated deprecated API usage** - Future-proofed against WebKit API removal
2. **Centralized context management** - Single source of truth for JavaScript contexts
3. **Improved error handling** - Graceful fallback when context unavailable
4. **Better lifecycle management** - Automatic cleanup prevents memory leaks
5. **Event-driven caching** - Leverages WebKit's window-object-cleared event correctly

## Testing

Build testing verified:
- All compilation errors resolved
- All 9 webkit_web_page_get_main_frame() warnings eliminated
- No new warnings introduced
- Binary builds successfully (221K)

## Conclusion

Phase 7 successfully eliminated all remaining "easy" deprecation warnings. The webkit_web_page_get_main_frame() deprecation was cleanly resolved through a well-architected caching solution that respects WebKit's Site Isolation design.

The remaining 72 WebKitDOM warnings represent the architectural boundary where deeper refactoring would be required. These are documented and can be addressed in future work if needed.

**Phase 7 Status: COMPLETE ✅**
