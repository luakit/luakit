# Code TODO/FIXME Analysis

**Date:** 2026-01-19
**Purpose:** Analyze all TODO/FIXME comments to determine if they can be resolved
**Status:** In Progress

---

## Summary

Found 9 TODO/FIXME items in the codebase. Analysis below shows which can be resolved, which are already correct, and which need further investigation.

---

## TODO/FIXME Items

### 1. ✅ RESOLVED: GError Memory Leak (download.c:174)

**Location:** `clib/download.c:174`

**Code:**
```c
static void
failed_cb(WebKitDownload* UNUSED(d), GError *error, download_t *download)
{
    // TODO does the GError error need a g_error_free(error)?
    /* save error message */
    if (download->error)
        g_free(download->error);
    download->error = g_strdup(error->message);
```

**Analysis:**

This is a **signal callback** for WebKitDownload's "failed" signal. According to GObject/WebKit signal documentation:

- **Signal parameters are owned by the caller** (WebKit)
- **Callbacks do NOT take ownership** of signal parameters
- **GError is automatically freed** by WebKit after callback returns
- **NO g_error_free() needed** in the callback

**WebKit Documentation Pattern:**
Signal callbacks receive borrowed references. The GError pointer is only valid during the callback. The code correctly copies the error message with `g_strdup()` for later use.

**Similar Pattern:**
Other WebKit signal handlers in luakit follow the same pattern - they copy data but don't free signal parameters.

**Verdict:** ✅ **Code is CORRECT, remove TODO comment**

**Action:** Remove the TODO comment, optionally add clarifying comment:
```c
static void
failed_cb(WebKitDownload* UNUSED(d), GError *error, download_t *download)
{
    /* GError is owned by WebKit, do not free */
    /* save error message */
    if (download->error)
        g_free(download->error);
    download->error = g_strdup(error->message);
```

---

### 2. 📋 RESOLVED: Token Rename (download.c:678)

**Location:** `clib/download.c:678`

**Code:**
```c
// TODO rename token, possibly to L_TK_CONTENT_LENGTH?
    luaH_class_add_property(&download_class, L_TK_TOTAL_SIZE,
```

**Analysis:**

This is a **naming consistency** suggestion. The property is called `total_size` in Lua but WebKit uses "Content-Length" header.

**Investigation:**
- Current token: `L_TK_TOTAL_SIZE`
- Lua property name: `total_size`
- Suggested: `L_TK_CONTENT_LENGTH`

**Recommendation:** This is a **cosmetic change** with low priority.

**Trade-offs:**
- ✅ Pro: Better alignment with HTTP terminology
- ❌ Con: No functional benefit
- ❌ Con: Token names are internal implementation details

**Verdict:** ✅ **Leave as-is** (total_size is clear and correct)

**Action:** Remove TODO comment or update to note this is intentional:
```c
/* Using total_size instead of content_length for clarity */
luaH_class_add_property(&download_class, L_TK_TOTAL_SIZE,
```

---

### 3. ⚠️ INVESTIGATE: Callback Failure Handling (extension/luajs.c:198)

**Location:** `extension/luajs.c:198`

**Code:**
```c
    /* TODO: handle callback failure? */
    luaH_object_push(L, ctx->ref);
    luaH_dofunction(L, argc + 3, 0);

    lua_settop(L, top);
    return promise->promise;
```

**Context:** This is in `luaJS_registered_function_callback()` which handles JavaScript→Lua calls via promises.

**Analysis:**

**Current Behavior:**
1. JavaScript calls Lua function
2. Lua function called via `luaH_dofunction(L, argc + 3, 0)`
3. If Lua function errors, promise is **never resolved or rejected**
4. JavaScript side waits forever

**Problem:**
- `luaH_dofunction` uses `lua_pcall` internally
- Errors are caught but not propagated
- Promise left in pending state

**Correct Handling Should:**
1. Check return value of `luaH_dofunction`
2. If error: reject the promise with error message
3. If success: promise is resolved by Lua code calling resolve/reject closures

**Recommended Fix:**
```c
/* Handle Lua callback errors by rejecting the promise */
int success = luaH_dofunction(L, argc + 3, 0);
if (!success) {
    /* Lua callback failed - reject the promise with error */
    const char *error_msg = lua_tostring(L, -1);
    JSCValue *error = jsc_value_new_string(context, error_msg ?: "Lua callback error");
    jsc_value_function_call(promise->reject, JSC_TYPE_VALUE, error, G_TYPE_NONE);
    g_object_unref(error);
    lua_pop(L, 1); /* pop error message */
}
```

**Impact:**
- **Current:** JavaScript promises hang on Lua errors (bad UX)
- **Fixed:** JavaScript receives rejection (proper error handling)

**Verdict:** ⚠️ **BUG - Should be fixed**

**Severity:** MEDIUM (degrades UX, doesn't crash)

---

### 4. 📋 DEFER: X-macro Table (log.c:204)

**Location:** `log.c:204`

**Code:**
```c
    /* Determine logging style */
    /* TODO: move to X-macro generated table? */

    gchar prefix_char, *style = "";
```

**Analysis:**

This is a **code organization** suggestion using X-macros for table generation.

**Current Approach:** Manual switch/if statements for log level formatting

**X-macro Approach:** Generate tables from macro definitions

**Trade-offs:**
- ✅ Pro: Less repetition
- ✅ Pro: Easier to add new log levels
- ❌ Con: More complex macro code
- ❌ Con: Harder to debug
- ❌ Con: No functional benefit

**Verdict:** 📋 **DEFER** - Nice-to-have refactoring, not a bug

**Priority:** LOW (code quality improvement, not a fix)

---

### 5. 📋 ARCHITECTURE: FFI Initialization (widgets/drawing_area.c:81)

**Location:** `widgets/drawing_area.c:81`

**Code:**
```c
    /* Store ref to ffi.new() */
    /* FIXME: Should do this before Lua code runs at all, but there's no good
     * way for random C code to hook into the Lua initialization stuff */
    if (!ffi_new_ref) {
```

**Analysis:**

This is an **architectural limitation**, not a bug.

**Problem:**
- FFI module needs to be loaded before drawing_area can use it
- No hook for C modules to run during Lua initialization
- Currently does lazy initialization on first use

**Current Solution:** Works correctly via lazy initialization

**Ideal Solution:** Would require:
1. Adding initialization hook system
2. Registering C module initializers
3. Calling them during Lua setup
4. Significant architectural change

**Impact:** None - lazy initialization works fine

**Verdict:** 📋 **DEFER** - Architecture limitation, not a bug

**Recommendation:** Update comment to note this is intentional:
```c
    /* Store ref to ffi.new() - initialized on first use since there's no
     * good way for C modules to hook into Lua initialization */
    if (!ffi_new_ref) {
```

---

### 6. 📋 UI CODE: Max Width Kludge (widgets/webview/auth.c:214)

**Location:** `widgets/webview/auth.c:214`

**Code:**
```c
    g_value_init(&max_width_chars, G_TYPE_INT);
    g_value_set_int(&max_width_chars, 32);
    /* TODO this is a kludge */
    g_object_set_property(G_OBJECT(msg_label), "max-width-chars", &max_width_chars);
```

**Analysis:**

**Current Code:** Uses GValue to set GTK property

**"Kludge" Comment:** Refers to verbose GValue code

**Cleaner Alternative:**
```c
    /* Set max width for label */
    g_object_set(G_OBJECT(msg_label), "max-width-chars", 32, NULL);
```

**Trade-offs:**
- ✅ Simpler, clearer code
- ✅ No GValue boilerplate
- ✅ Same functionality

**Verdict:** ✅ **Easy fix** - Use g_object_set() instead

**Severity:** LOW (code quality, not a bug)

---

### 7. ✅ RESOLVED: Password Memory (widgets/webview/auth.c:257)

**Location:** `widgets/webview/auth.c:257`

**Code:**
```c
    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(auth_data, &login, &password);
    show_auth_dialog(auth_data, login, password);
    /* TODO: g_free login and password? */
```

**Analysis:**

Need to check `luakit_find_password()` implementation:

```c
static void
luakit_find_password(LuakitAuthData *auth_data, const gchar **login, const gchar **password)
{
    lua_State *L = common.L;
    // ...
    gint ret = luaH_object_emit_signal(L, -2, "store-password", 1, LUA_MULTRET);
    if (ret >= 2) {
        *password = luaL_checkstring(L, -1);  // ← Returns pointer to Lua string
        *login = luaL_checkstring(L, -2);     // ← Returns pointer to Lua string
    }
}
```

**Key Finding:** `luaL_checkstring()` returns **pointer to Lua-owned string**

**Lua String Ownership:**
- Strings are on the Lua stack
- Valid until stack is modified (popped, pushed over, etc.)
- **NOT** dynamically allocated strings
- **NO** g_free() needed

**Verification:**
After the call, code does:
1. `show_auth_dialog(auth_data, login, password);` - Uses strings immediately
2. Function returns
3. Strings are still on Lua stack (not popped)

**Potential Issue:** If Lua stack is modified elsewhere before `show_auth_dialog`, strings become invalid.

**Investigation of show_auth_dialog:**
Let me check if it uses the strings or stores them...

**Verdict:** ✅ **Code is CORRECT** - Lua owns the strings, no g_free() needed

**However:** There's a **subtle bug** - if the Lua stack is modified before `show_auth_dialog` uses the strings, they become invalid.

**Better Approach:**
```c
    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(auth_data, &login, &password);

    /* Copy strings since they're Lua-owned and stack may be modified */
    gchar *login_copy = login ? g_strdup(login) : NULL;
    gchar *password_copy = password ? g_strdup(password) : NULL;

    show_auth_dialog(auth_data, login_copy, password_copy);

    /* Now we own these strings, so free them */
    g_free(login_copy);
    g_free(password_copy);
```

**Investigation of show_auth_dialog:**

The function calls:
```c
auth_data->login_entry = table_add_entry(table, 0, "Username:", login, NULL);
auth_data->password_entry = table_add_entry(table, 1, "Password:", password, NULL);
```

Which calls:
```c
if (value)
    gtk_entry_set_text(GTK_ENTRY(entry), value);
```

**gtk_entry_set_text()** **copies the string** internally (standard GTK behavior).

**Timeline:**
1. `luakit_find_password()` returns pointers to Lua stack strings
2. `show_auth_dialog()` called immediately (no stack modification)
3. `gtk_entry_set_text()` copies strings to GTK widgets
4. Strings are now owned by GTK (safe)

**Verdict:** ✅ **Code is CORRECT** - Strings are copied by GTK before stack is modified

**However:** Code is **fragile** - adding code between the calls could break it

**Recommendation:** Add comment to clarify:
```c
    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(auth_data, &login, &password);
    /* Strings are Lua-owned, use immediately before stack is modified */
    show_auth_dialog(auth_data, login, password);
```

**Severity:** N/A (code works correctly, just fragile)

---

### 8. ✅ RESOLVED: GList Memory (widgets/webview/history.c:27)

**Location:** `widgets/webview/history.c:27`

**Code:**
```c
    // TODO do these new GLists need to be freed?
    gint backlen = g_list_length(
            webkit_back_forward_list_get_back_list(bflist));
    gint forwardlen = g_list_length(
            webkit_back_forward_list_get_forward_list(bflist));
```

**Analysis:**

According to WebKit2GTK documentation:

**`webkit_back_forward_list_get_back_list()`:**
- Returns: (transfer none) - **Caller does NOT own the list**
- List is owned by WebKitBackForwardList
- Valid until list is modified

**`webkit_back_forward_list_get_forward_list()`:**
- Returns: (transfer none) - **Caller does NOT own the list**
- List is owned by WebKitBackForwardList
- Valid until list is modified

**`g_list_length()`:**
- Does NOT modify the list
- Safe to call on borrowed references

**Verdict:** ✅ **Code is CORRECT** - Lists are borrowed, no g_list_free() needed

**Action:** Remove TODO comment, optionally add clarifying comment:
```c
    /* These lists are owned by WebKitBackForwardList, do not free */
    gint backlen = g_list_length(
            webkit_back_forward_list_get_back_list(bflist));
    gint forwardlen = g_list_length(
            webkit_back_forward_list_get_forward_list(bflist));
```

---

### 9. 📋 DEFER: Signal Emission Location (widgets/webview.c:1337)

**Location:** `widgets/webview.c:1337`

**Code:**
```c
    /* TODO: move signal emission to somewhere else */
    if (!ipc->creation_notified) {
```

**Analysis:**

This is about **code organization** - where to emit the 'web-extension-created' signal.

**Current Location:** During webview initialization

**Concern:** Signal emission mixed with widget setup

**Better Location:**
- Dedicated signal handling module
- IPC module when web process connects
- Separate initialization hook

**Impact:** None - signal works correctly where it is

**Verdict:** 📋 **DEFER** - Refactoring suggestion, not a bug

**Priority:** LOW (code organization)

---

## Summary Table

| # | Location | Type | Severity | Status | Action |
|---|----------|------|----------|--------|--------|
| 1 | download.c:174 | GError memory | N/A | ✅ Code correct | Remove TODO |
| 2 | download.c:678 | Token naming | N/A | ✅ Intentional | Remove TODO |
| 3 | luajs.c:198 | Callback failure | MEDIUM | ⚠️ **BUG** | **Fix needed** |
| 4 | log.c:204 | X-macro refactor | LOW | 📋 Defer | Low priority |
| 5 | drawing_area.c:81 | FFI init | N/A | 📋 Architecture | Update comment |
| 6 | auth.c:214 | GValue kludge | LOW | ✅ Easy fix | Use g_object_set |
| 7 | auth.c:257 | Password memory | N/A | ✅ Code correct | Add comment |
| 8 | history.c:27 | GList memory | N/A | ✅ Code correct | Remove TODO |
| 9 | webview.c:1337 | Signal location | LOW | 📋 Defer | Low priority |

---

## Recommendations

### High Priority (Bugs)

1. **⚠️ Fix luajs.c:198** - Handle Lua callback failures by rejecting promises
   - **Impact:** Better error handling, prevents hanging promises
   - **Effort:** ~30 minutes
   - **Risk:** Low
   - **Status:** FIX NEEDED

### Low Priority (Code Quality)

3. **✅ Remove/Update TODO comments** for items 1, 2, 7, 8
   - Already correct, just need comment cleanup
   - Add clarifying comments where helpful

4. **✅ Fix auth.c:214** - Replace GValue code with g_object_set()
   - Simple cleanup, no functional change
   - Effort: 5 minutes

5. **📋 Defer** items 4, 5, 9 - Low priority refactoring
   - No functional issues
   - Can be addressed in future cleanup PRs

---

## Next Steps

1. ✅ ~~Investigate `show_auth_dialog()` to determine auth.c:257 severity~~ - DONE (code is correct)
2. ⚠️ Implement promise rejection in luajs.c:198 - **NEEDED**
3. ✅ Clean up resolved TODO comments - **EASY WINS**
4. ✅ Fix GValue kludge in auth.c:214 - **EASY WIN**
5. Create PR with fixes

---

## Proposed Fixes

### Fix #1: Promise Rejection on Lua Callback Failure (luajs.c:198)

**File:** `extension/luajs.c`
**Lines:** 196-204
**Priority:** HIGH (user-facing bug)

**Current Code:**
```c
    /* TODO: handle callback failure? */
    luaH_object_push(L, ctx->ref);
    luaH_dofunction(L, argc + 3, 0);

    lua_settop(L, top);
    return promise->promise;
}
```

**Fixed Code:**
```c
    /* Call Lua callback and handle errors by rejecting the promise */
    luaH_object_push(L, ctx->ref);
    int success = luaH_dofunction(L, argc + 3, 0);

    if (!success && lua_gettop(L) > top) {
        /* Lua callback failed - reject the promise with error message */
        const char *error_msg = lua_tostring(L, top + 1);
        if (error_msg) {
            JSCValue *error = jsc_value_new_string(context, error_msg);
            JSCValue *undefined = jsc_value_function_call(promise->reject,
                                                          JSC_TYPE_VALUE, error,
                                                          G_TYPE_NONE);
            g_object_unref(undefined);
            g_object_unref(error);
        }
    }

    lua_settop(L, top);
    return promise->promise;
}
```

**Testing:**
- Call Lua function that throws error from JavaScript
- Verify promise is rejected with error message
- Verify normal success path still works

---

### Fix #2: Simplify GValue Usage (auth.c:214)

**File:** `widgets/webview/auth.c`
**Lines:** 211-215
**Priority:** LOW (code quality)

**Current Code:**
```c
    gtk_label_set_line_wrap(GTK_LABEL(msg_label), TRUE);
    GValue max_width_chars = G_VALUE_INIT;
    g_value_init(&max_width_chars, G_TYPE_INT);
    g_value_set_int(&max_width_chars, 32);
    /* TODO this is a kludge */
    g_object_set_property(G_OBJECT(msg_label), "max-width-chars", &max_width_chars);
```

**Fixed Code:**
```c
    gtk_label_set_line_wrap(GTK_LABEL(msg_label), TRUE);
    g_object_set(G_OBJECT(msg_label), "max-width-chars", 32, NULL);
```

**Benefit:** Simpler, clearer code, same functionality

---

### Fix #3-6: Comment Updates (Multiple Files)

**Priority:** LOW (documentation)

**download.c:174** - Remove TODO, add clarification:
```c
static void
failed_cb(WebKitDownload* UNUSED(d), GError *error, download_t *download)
{
    /* GError is owned by WebKit signal system, do not free */
    /* save error message */
    if (download->error)
        g_free(download->error);
    download->error = g_strdup(error->message);
```

**download.c:678** - Remove TODO (naming is intentional):
```c
/* total_size property (WebKit calls this Content-Length) */
luaH_class_add_property(&download_class, L_TK_TOTAL_SIZE,
```

**auth.c:257** - Remove TODO, add clarification:
```c
    const gchar *login = NULL;
    const gchar *password = NULL;
    luakit_find_password(auth_data, &login, &password);
    /* Strings are Lua-owned, use immediately before stack is modified */
    show_auth_dialog(auth_data, login, password);

    return TRUE;
}
```

**history.c:27** - Remove TODO, add clarification:
```c
    /* Lists are owned by WebKitBackForwardList, do not free */
    gint backlen = g_list_length(
            webkit_back_forward_list_get_back_list(bflist));
    gint forwardlen = g_list_length(
            webkit_back_forward_list_get_forward_list(bflist));
```

**drawing_area.c:81** - Update FIXME to note this is intentional:
```c
    /* Store ref to ffi.new() - initialized on first use since there's no
     * C module initialization hook before Lua code runs */
    if (!ffi_new_ref) {
```

---

## Testing Plan

### For Promise Rejection Fix

1. Create test Lua function that errors:
   ```lua
   page:register_js_callback("test_error", function()
       error("Test error message")
   end)
   ```

2. Call from JavaScript and verify rejection:
   ```javascript
   test_error().catch(err => console.log("Caught:", err))
   ```

3. Verify normal success case still works

### For Comment Updates

- Code review only (no functional changes)
- Verify comments are accurate

---

**Status:** Analysis complete, one bug found, fixes proposed
**Date:** 2026-01-19
**Bug Count:** 1 (promise rejection)
**Easy Wins:** 6 (comment/code cleanup)
