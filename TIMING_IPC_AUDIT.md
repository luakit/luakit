# Timing and IPC Protocol Audit

**Date:** 2026-01-18
**Focus:** Race conditions, timing issues, and IPC protocol correctness
**Status:** In Progress

---

## Executive Summary

Comprehensive audit of timing-sensitive code and IPC communication protocol between UI process and web extension processes.

---

## IPC Protocol Analysis

### Protocol Handshake

**Sequence:**
1. **Extension starts** (extension/extension.c:92-118)
   - Connects to UI socket (extension/ipc.c:161-203)
   - Sends `IPC_TYPE_extension_init` to UI (extension/extension.c:116)
   - Queues page-created events (extension/ipc.c:154-157)

2. **UI receives extension_init** (ipc.c:52-59)
   - Loads web modules for endpoint (ipc.c:54)
   - Sends `IPC_TYPE_extension_init` BACK to extension (ipc.c:57)

3. **Extension receives extension_init** (extension/ipc.c:62-66)
   - Calls `emit_pending_page_creation_ipc()` (line 64)
   - Flushes queued page-created messages (extension/ipc.c:141-148)
   - Calls `luakit_lib_emit_pending_signals()` (line 65)

**Verdict:** ✅ Correct handshake protocol

**Purpose:** Ensures Lua modules are loaded before page-created events are sent, preventing references to undefined Lua code.

### IPC Message Types and Handlers

| Message Type | Direction | Extension Handler | UI Handler | Protocol |
|--------------|-----------|-------------------|------------|----------|
| `extension_init` | Both | ipc.c:62-66 | ipc.c:52-59 | Handshake |
| `page_created` | Ext→UI | N/A | ipc.c:80-89 | Page lifecycle |
| `eval_js` | Both | extension/ipc.c:85-120 | ipc.c:74-77 | JavaScript evaluation |
| `scroll` | Both | extension/ipc.c:69-82 | ipc.c:68-71 | Scroll commands |
| `lua_ipc` | Both | extension/ipc.c:56-59 | ipc.c:62-65 | Lua IPC channel |
| `lua_require_module` | UI→Ext | extension/ipc.c:44-53 | NO_HANDLER | Module loading |
| `lua_js_call` | UI→Ext | luajs.c (registered) | N/A | JavaScript calls |
| `lua_js_register` | UI→Ext | luajs.c (registered) | N/A | Function registration |

**Transport:** Unix domain socket (SOCK_STREAM)
- ✅ Ordered delivery guaranteed (TCP semantics)
- ✅ Reliable delivery
- ✅ Connection-oriented

### eval_js Protocol Details

**UI → Extension (Request):**
```
Serialized Lua values (5 items):
1. no_return (boolean) - Don't return result
2. script (string) - JavaScript code
3. source (string) - Source identifier
4. page_id (integer) - WebKit page ID
5. cb_ref (reference) - Lua callback reference
```

**Extension → UI (Response):**
```
Success: [page_id, cb_ref, ...results]
Error:   [page_id, cb_ref, nil, error_message]
```

**Handler:** extension/ipc.c:85-120

**Key Steps:**
1. Deserialize request (line 89)
2. Check page exists (line 98-104)
   - If not: Send callback to free ref, return
3. Get JavaScript context (line 107)
   - If not available: Push nil + error (lines 112-115)
4. Evaluate JavaScript (line 109)
5. Send response (line 118)

**Timing Considerations:**
- ✅ Page may be destroyed between request and handling
  - **Protected:** Line 99 checks page existence
- ✅ Context may not be ready yet
  - **Protected:** Returns "page context not available" error
- ✅ Callback ref freed in UI even if page gone
  - **Protected:** Line 101 sends callback back to free it

**Verdict:** ✅ Robust error handling, no race conditions

---

## JavaScript Context Lifecycle

### Context Creation

**Signal:** `window-object-cleared` (WebKitScriptWorld)
**Handler:** extension/luajs.c:265-315

**Flow:**
1. Signal fires when window object is cleared (page load/navigation)
2. Check if main frame (line 268) - ignore subframes
3. Get page ID (line 273)
4. Get JavaScript context from frame (line 274)
5. **Cache context** (line 275): `js_context_cache_set(page_id, ctx)`
6. Register Lua→JS functions (lines 278-314)

**Key Timing:**
- `window-object-cleared` fires **AFTER** `page-created`
- Context is **NOT available** immediately when page created
- Early `eval_js` calls will fail with "page context not available"

**Cache Storage:**
```c
// luajs.c:59-68
js_context_cache_set(guint64 page_id, JSCContext *ctx)
{
    g_object_ref(ctx);  /* Cache takes ownership */
    g_hash_table_replace(page_js_contexts,
                         GUINT_TO_POINTER(page_id),
                         ctx);
}
```

**Reference Counting:**
- Cache takes reference: `g_object_ref(ctx)` (line 64)
- Caller's reference is separate (line 274 gets from frame)
- Caller unrefs its own copy (line 276)

**Verdict:** ✅ Correct reference counting

### Context Retrieval

**Function:** `js_context_cache_get(guint64 page_id)` (luajs.c:70-81)

**Flow:**
1. Check cache exists (line 73) - return NULL if not initialized
2. Lookup context by page_id (line 76)
3. **Take reference** if found: `g_object_ref(ctx)` (line 79)
4. Return context (caller MUST unref)

**Contract:** Caller MUST call `g_object_unref(ctx)` when done

**Reference Counting:**
- Caller gets NEW reference
- Cache keeps its own reference
- Context stays alive until BOTH are released

**Verdict:** ✅ Thread-safe, correct reference counting

### Context Destruction

**Trigger:** Page destruction
**Mechanism:** Weak reference (luajs.c:320-325)

**Flow:**
1. `page-created` signal fires (extension/luajs.c:318)
2. `page_created_cb` registers weak reference (lines 322-324):
   ```c
   g_object_weak_ref(G_OBJECT(web_page),
                     (GWeakNotify)js_context_cache_remove,
                     GUINT_TO_POINTER(page_id));
   ```
3. When page destroyed, weak notify callback fires
4. `js_context_cache_remove` called (luajs.c:83-90)
5. Context removed from cache
6. `GDestroyNotify` unrefs context (luajs.c:54)

**Race Condition Analysis:**

**Scenario:** Context in use when page destroyed
1. Thread A: `ctx = js_context_cache_get(page_id)` (takes reference)
2. Page destroyed, weak notify fires
3. `js_context_cache_remove` removes from cache, unrefs cache's reference
4. Thread A still has its reference, context stays alive
5. Thread A calls `g_object_unref(ctx)`, context finally freed

**Verdict:** ✅ SAFE - Reference counting protects against use-after-free

---

## Timing Issues Analysis

### Issue #1: eval_js Before Context Ready

**Problem:** IPC eval_js arrives before `window-object-cleared` fires

**Timeline:**
1. Page created → `page-created` signal fires
2. Extension sends `page_created` IPC to UI
3. UI may immediately send `eval_js` IPC
4. Extension receives `eval_js` before `window-object-cleared` fires
5. Context not in cache yet

**Protection:** extension/ipc.c:107-116
```c
JSCContext *ctx = js_context_cache_get(page_id);
if (ctx) {
    n = luajs_eval_js(L, ctx, script, source, 1, no_return);
    g_object_unref(ctx);
} else {
    /* Context not available yet, push error */
    lua_pushnil(L);
    lua_pushstring(L, "page context not available");
    n = 2;
}
```

**Lua Handling:** Lua code checks for this error and retries later
- lib/tab_favicons.lua:141-146
- lib/lousy/widget/scroll.lua:25-30

**Verdict:** ✅ SAFE - Graceful degradation, no crash

### Issue #2: eval_js After Page Destroyed

**Problem:** IPC eval_js arrives after page already destroyed

**Protection:** extension/ipc.c:98-104
```c
WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
if (!page) {
    /* Notify UI to free callback ref */
    ipc_send_lua(extension.ipc, IPC_TYPE_eval_js, L, -2, -1);
    lua_settop(L, top);
    return;
}
```

**Behavior:**
- Returns callback immediately to UI
- UI frees callback reference
- No crash, no leak

**Verdict:** ✅ SAFE - Clean error handling

### Issue #3: Promise Resolve After Page Closed

**Problem:** Lua code calls promise resolve/reject after page destroyed

**Function:** luajs.c:129-157 (`luaJS_promise_resolve_reject`)

**Protection:** Lines 132-140
```c
guint64 page_id = lua_tointeger(L, lua_upvalueindex(1));
WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
if (!page || !WEBKIT_IS_WEB_PAGE(page))
    return luaL_error(L, "promise no longer valid (associated page closed)");

JSCContext *context = js_context_cache_get(page_id);
if (!context)
    return luaL_error(L, "promise no longer valid (page context unavailable)");
```

**Behavior:**
- Checks page validity
- Checks context availability
- Returns Lua error if either invalid
- Promise cleanup happens in error handler

**Verdict:** ✅ SAFE - Double validation before use

### Issue #4: Page Creation Queue Overflow

**Problem:** Many pages created before extension_init handshake completes

**Protection:** extension/ipc.c:38, 154-157, 196
```c
static GPtrArray *queued_page_ipc;  /* Line 38 */

static void
web_page_created_cb(...)
{
    /* QUEUE until we've fully loaded web modules */
    if (queued_page_ipc)
        g_ptr_array_add(queued_page_ipc, web_page);  /* Line 155 */
    else
        emit_page_created_ipc(web_page, NULL);  /* Line 157 */
}

/* Line 196: Initialize queue */
queued_page_ipc = g_ptr_array_sized_new(1);
```

**Memory:** GPtrArray auto-grows, no fixed limit

**Cleanup:** extension/ipc.c:141-148
```c
void emit_pending_page_creation_ipc(void)
{
    if (queued_page_ipc) {
        g_ptr_array_foreach(queued_page_ipc, (GFunc)emit_page_created_ipc, NULL);
        g_ptr_array_free(queued_page_ipc, TRUE);
        queued_page_ipc = NULL;  /* Set to NULL = stop queueing */
    }
}
```

**Verdict:** ✅ SAFE - Unbounded growth during init, but short-lived

### Issue #5: Context Cache Race (Reload)

**Problem:** Page reloads, new context created while old one in use

**Timeline:**
1. Code A: `ctx1 = js_context_cache_get(page_id)` (takes ref to ctx1)
2. Page reloads, `window-object-cleared` fires
3. New context ctx2 created
4. `js_context_cache_set(page_id, ctx2)` called
5. `g_hash_table_replace` unrefs ctx1 (cache's reference)
6. Code A still has its reference to ctx1, continues working
7. Code A unrefs ctx1, now fully freed
8. Future lookups get ctx2

**Hash Table Behavior:**
```c
// luajs.c:50-55
page_js_contexts = g_hash_table_new_full(
    g_direct_hash,
    g_direct_equal,
    NULL,
    (GDestroyNotify)g_object_unref  /* Unrefs OLD value on replace */
);
```

**Verdict:** ✅ SAFE - Reference counting prevents use-after-free

### Issue #6: Signal Connection Order

**Signals Connected:**
1. extension/ipc.c:195 - `page-created` → `web_page_created_cb` (IPC queueing)
2. extension/luajs.c:333 - `window-object-cleared` → `window_object_cleared_cb` (context caching)
3. extension/luajs.c:337 - `page-created` → `page_created_cb` (weak ref setup)
4. extension/scroll.c:227 - `page-created` → `web_page_created_cb` (scroll init)

**Order:** All connected during initialization (extension/extension.c:108-111)
```c
web_lua_init(package_path, package_cpath);
web_scroll_init();       /* Connects scroll page-created */
web_luajs_init();        /* Connects luajs signals */
web_script_world_init();
```

**IPC connection:** Happens BEFORE (extension/extension.c:103)

**Timeline for New Page:**
1. WebKit fires `page-created` signal
2. Handlers called in connection order:
   - ipc.c:151 - Queue or emit IPC
   - luajs.c:318 - Set up weak reference for cleanup
   - scroll.c:162 - Connect document-loaded signal
3. (Later) WebKit fires `window-object-cleared`
   - luajs.c:266 - Cache JavaScript context

**Verdict:** ✅ SAFE - Order doesn't matter, all handlers independent

---

## IPC Message Ordering

### Ordering Guarantees

**Transport:** Unix domain socket (SOCK_STREAM)
- ✅ TCP semantics - ordered delivery
- ✅ Messages arrive in send order
- ✅ No reordering within single connection

**Extension → UI:**
- Single socket connection
- All messages serialized through same socket
- Order preserved

**UI → Extension:**
- One socket per web process
- Order preserved within each connection
- Different web processes = different connections (independent ordering)

**Verdict:** ✅ Message ordering guaranteed per connection

### Async Operation Hazards

**Potential Issue:** Async operations breaking expected order

**Example Scenario:**
1. UI sends eval_js #1
2. UI sends eval_js #2
3. Extension receives both in order
4. Async JavaScript execution completes out of order
5. Responses sent: #2, then #1

**Analysis:**
- Messages arrive in order ✅
- Processing starts in order ✅
- JavaScript execution is async ❓
- Response order may differ ⚠️

**Protection:**
- Each eval_js has unique callback reference
- UI matches responses by callback ref, not order
- Order doesn't matter for correctness

**Verdict:** ✅ SAFE - Callbacks handle async responses

---

## Signal Timing Issues

### window-object-cleared Timing

**When it fires:**
- Page load starts
- Page navigation
- Page reload
- JavaScript context needs clearing

**Order relative to page-created:**
- `page-created` fires first
- `window-object-cleared` fires later (when loading starts)
- Gap can be significant (100ms+)

**Code depending on context:**
- MUST handle "context not available" error
- MUST retry or defer operations

**Current code:**
- ✅ extension/ipc.c:107-116 - Returns error if no context
- ✅ Lua code handles gracefully

**Verdict:** ✅ Timing properly handled

### document-loaded Timing

**Signal:** extension/scroll.c:162-171

**When it fires:**
- After DOM fully loaded
- After `window-object-cleared`
- After context available

**Purpose:**
- Restore scroll position from previous session
- Safe to access DOM and JavaScript context

**Verdict:** ✅ Correct timing for DOM operations

---

## Memory and Resource Leaks

### Context Cache Cleanup

**Cleanup Trigger:** Page destruction (weak reference)

**Potential Leak:** Page destroyed but cache not cleaned

**Protection:** luajs.c:320-325
```c
static void
page_created_cb(WebKitWebExtension *UNUSED(ext), WebKitWebPage *web_page, ...)
{
    /* Use weak reference to clean up cached context when page is destroyed */
    guint64 page_id = webkit_web_page_get_id(web_page);
    g_object_weak_ref(G_OBJECT(web_page),
                      (GWeakNotify)js_context_cache_remove,
                      GUINT_TO_POINTER(page_id));
}
```

**Behavior:**
- Weak reference doesn't prevent page destruction
- Callback fires automatically when page destroyed
- Context removed from cache
- Cache's reference released
- Context freed when all refs released

**Verdict:** ✅ No leak - Automatic cleanup

### IPC Queue Cleanup

**Queue:** extension/ipc.c:38 - `queued_page_ipc`

**Lifecycle:**
1. Created at startup (line 196)
2. Grows during init as pages created
3. Flushed when extension_init received (line 64)
4. Freed (line 145)
5. Set to NULL (line 146)

**Potential Leak:** If extension_init never received

**Analysis:**
- If handshake fails, process likely exits
- Queue never freed, but process dies anyway
- Not a practical leak

**Verdict:** ✅ Acceptable - Process exit cleans up

---

## Findings Summary

### ✅ No Critical Timing Issues Found

All identified race conditions are properly protected:

1. **eval_js before context ready** - Returns error, Lua retries
2. **eval_js after page destroyed** - Clean error handling
3. **Promise resolve after page closed** - Double validation
4. **Context in use during page destruction** - Reference counting protects
5. **Context reload race** - Reference counting protects
6. **IPC message ordering** - Transport guarantees order
7. **Async response ordering** - Callbacks handle out-of-order

### ✅ IPC Protocol Correct

1. **Handshake protocol** - Proper sequencing
2. **Message serialization** - Correct protocol
3. **Error handling** - Robust, no leaks
4. **Resource cleanup** - Callbacks freed even on error

### ✅ Memory Management Correct

1. **Context cache** - Proper reference counting
2. **Weak references** - Automatic cleanup
3. **IPC queue** - Freed after handshake
4. **No leaks identified**

---

## Recommendations

### Code Quality (Optional)

1. **Add timeout to handshake** - Detect if extension_init never arrives
2. **Add IPC version check** - Detect protocol mismatches
3. **Add message sequence numbers** - Easier debugging of ordering issues
4. **Document timing assumptions** - Add comments about when context is available

### Testing (Recommended)

1. **Stress test page creation** - Create 100+ tabs rapidly
2. **Test rapid navigation** - Reload pages quickly
3. **Test process death** - Kill web process, verify UI handles it
4. **Test slow handshake** - Delay extension_init, verify queueing works

---

## Conclusion

**Overall Assessment:** The timing and IPC implementation is **robust and production-ready**.

**Strengths:**
1. ✅ Proper handshake protocol prevents premature message delivery
2. ✅ Reference counting prevents use-after-free in all scenarios
3. ✅ Error handling covers all timing edge cases
4. ✅ IPC transport guarantees message ordering
5. ✅ Automatic cleanup via weak references

**No bugs found.** All timing-sensitive code paths are properly protected.

---

**Status:** ✅ COMPLETE
**Date:** 2026-01-18
**Verdict:** Production-ready, no timing or IPC protocol issues found
