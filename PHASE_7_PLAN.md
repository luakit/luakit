# Phase 7: Remaining Deprecation Warnings - Attack Plan

**Date:** 2026-01-18
**Current Warnings:** 81
**Target:** Eliminate 9-20 warnings
**Status:** Planning Complete

---

## Problem Analysis

### webkit_web_page_get_main_frame() - 9 Warnings

**Root Cause:** Deprecated due to Site Isolation work in WebKit

**Current Pattern (WRONG):**
```c
WebKitFrame *frame = webkit_web_page_get_main_frame(page);  // DEPRECATED!
JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, world);
// ... use ctx ...
g_object_unref(ctx);
```

**Why It's Deprecated:**
- Site isolation means main frame might be in different process
- WebKit team is moving to UI process APIs
- No direct replacement available yet

**WebKit's Recommendation:**
> Get the frame from script world on the window-object-cleared event

---

## Solution Strategy

### Option 1: Cache JSCContext per Page ✅ **RECOMMENDED**

**Approach:**
- Store JSCContext for each page_id in a hash table
- Update cache on `window-object-cleared` event (we already handle this!)
- Reuse cached context instead of calling `get_main_frame()`

**Implementation:**
```c
/* Global context cache */
static GHashTable *page_js_contexts = NULL;  // page_id -> JSCContext

/* In window_object_cleared_cb (extension/luajs.c:211) */
static void
window_object_cleared_cb(WebKitScriptWorld *world, WebKitWebPage *web_page,
                         WebKitFrame *frame, gpointer user_data)
{
    if (!webkit_frame_is_main_frame(frame))
        return;

    /* Cache the JSContext for this page */
    guint64 page_id = webkit_web_page_get_id(web_page);
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, world);

    /* Replace old context if exists */
    g_hash_table_replace(page_js_contexts,
                         GUINT_TO_POINTER(page_id),
                         ctx);  // Hash table owns the reference

    /* ... rest of existing code ... */
}

/* Getter function */
JSCContext *
get_cached_js_context(guint64 page_id)
{
    JSCContext *ctx = g_hash_table_lookup(page_js_contexts, GUINT_TO_POINTER(page_id));
    if (ctx)
        g_object_ref(ctx);  // Caller must unref
    return ctx;
}

/* Replace all uses */
// OLD:
JSCContext *context = webkit_frame_get_js_context(
    webkit_web_page_get_main_frame(page));  // DEPRECATED

// NEW:
guint64 page_id = webkit_web_page_get_id(page);
JSCContext *context = get_cached_js_context(page_id);
if (!context)
    return luaL_error(L, "page context not available");
```

**Files to Modify:**
1. extension/luajs.c (add cache, modify window_object_cleared_cb)
2. extension/ipc.c (use cache instead of get_main_frame)
3. extension/scroll.c (use cache instead of get_main_frame)
4. extension/clib/dom_document.c (use cache instead of get_main_frame)
5. extension/clib/dom_element.c (use cache instead of get_main_frame)

**Expected Result:** 9 warnings eliminated (81 → 72)

---

### Option 2: Use Frame from Event Callbacks

**Approach:**
- Many places already receive WebKitWebPage in event callbacks
- Some callbacks also receive WebKitFrame directly
- Pass frame through callback data structures

**Issues:**
- More invasive changes to callback structures
- Not all call sites have frame available
- More complex data flow

**Verdict:** More complex than Option 1, skip for now

---

## Implementation Plan

### Step 1: Create Context Cache Infrastructure

**File:** extension/luajs.c or new extension/js_context_cache.c

```c
#include <glib.h>
#include <jsc/jsc.h>

/* Global cache: page_id -> JSCContext */
static GHashTable *page_js_contexts = NULL;

void
js_context_cache_init(void)
{
    if (page_js_contexts)
        return;

    page_js_contexts = g_hash_table_new_full(
        g_direct_hash,
        g_direct_equal,
        NULL,
        (GDestroyNotify)g_object_unref  /* Unref context when removed */
    );
}

void
js_context_cache_set(guint64 page_id, JSCContext *ctx)
{
    g_assert(page_js_contexts);
    g_assert(ctx);

    g_object_ref(ctx);  /* Cache takes ownership */
    g_hash_table_replace(page_js_contexts,
                         GUINT_TO_POINTER(page_id),
                         ctx);
}

JSCContext *
js_context_cache_get(guint64 page_id)
{
    g_assert(page_js_contexts);

    JSCContext *ctx = g_hash_table_lookup(page_js_contexts,
                                          GUINT_TO_POINTER(page_id));
    if (ctx)
        g_object_ref(ctx);  /* Caller must unref */
    return ctx;
}

void
js_context_cache_remove(guint64 page_id)
{
    g_assert(page_js_contexts);
    g_hash_table_remove(page_js_contexts, GUINT_TO_POINTER(page_id));
}
```

### Step 2: Update window-object-cleared Handler

**File:** extension/luajs.c

Modify `window_object_cleared_cb` to cache context:

```c
static void
window_object_cleared_cb(WebKitScriptWorld *world, WebKitWebPage *web_page,
                         WebKitFrame *frame, gpointer user_data)
{
    if (!webkit_frame_is_main_frame(frame))
        return;

    guint64 page_id = webkit_web_page_get_id(web_page);
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, world);

    /* Cache the context for later use */
    js_context_cache_set(page_id, ctx);

    /* ... existing code continues ... */
    g_object_unref(ctx);  /* Cache holds its own reference */
}
```

### Step 3: Replace get_main_frame() Calls

**Location 1:** extension/luajs.c:84-85
```c
// OLD:
JSCContext *context = webkit_frame_get_js_context(
    webkit_web_page_get_main_frame(page));

// NEW:
guint64 page_id = webkit_web_page_get_id(page);
JSCContext *context = js_context_cache_get(page_id);
if (!context)
    return luaL_error(L, "promise no longer valid (page context unavailable)");
```

**Location 2:** extension/ipc.c:105-107
```c
// OLD:
WebKitFrame *frame = webkit_web_page_get_main_frame(page);
WebKitScriptWorld *world = webkit_script_world_get_default();
JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, world);

// NEW:
guint64 page_id = webkit_web_page_get_id(page);
JSCContext *ctx = js_context_cache_get(page_id);
if (!ctx)
    return;  /* Page context not available */
```

**Location 3:** extension/scroll.c:77-79, 185
```c
// OLD:
WebKitFrame *frame = webkit_web_page_get_main_frame(web_page);
WebKitScriptWorld *world = extension.script_world;
JSCContext *ctx = webkit_frame_get_js_context_for_script_world(frame, world);

// NEW:
guint64 page_id = webkit_web_page_get_id(web_page);
JSCContext *ctx = js_context_cache_get(page_id);
if (!ctx)
    return;  /* Page not ready yet */
```

**Locations 4-6:** extension/clib/dom_document.c and extension/clib/dom_element.c

Similar replacements in helper functions.

### Step 4: Handle Page Destruction

Add cache cleanup when pages are destroyed:

```c
static void
page_destroyed_cb(WebKitWebPage *web_page, gpointer user_data)
{
    guint64 page_id = webkit_web_page_get_id(web_page);
    js_context_cache_remove(page_id);
}
```

Connect signal in `web_luajs_init()`.

---

## Testing Plan

1. **Build Test:** Verify deprecation warnings reduced
2. **Runtime Test:** Ensure JavaScript evaluation still works
3. **Page Lifecycle Test:** Create/destroy pages, verify no leaks
4. **Follow Mode Test:** Test hint clicking (uses JS heavily)
5. **Form Filling Test:** Verify form interaction works

---

## Expected Results

- **Warnings Eliminated:** 9 (81 → 72)
- **Risk:** LOW (caching pattern is straightforward)
- **Effort:** 2-3 hours
- **Benefits:**
  - Eliminates all webkit_web_page_get_main_frame() warnings
  - Improves performance (cached context vs repeated lookups)
  - Future-proof approach
  - Clean, maintainable code

---

## Next Steps After This

After eliminating these 9 warnings (72 remaining), evaluate:

1. **Type checking macros** (24 warnings) - MEDIUM effort
2. **Document APIs** (some easy wins possible)
3. **Event system** (20 warnings) - HIGH effort, architectural
4. **Navigation** (6 warnings) - HIGH effort, architectural

---

**Status:** Ready to implement
**Author:** Claude
**Date:** 2026-01-18
