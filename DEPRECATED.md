# Deprecated Functions

This document lists all deprecated functions in luakit and provides migration
guidance for users and developers.

**Last Updated:** 2026-01-18

## lousy.util Functions

### `lousy.util.mkdir(dir)`

**Status:** Deprecated (will be removed in a future version)

**Reason:** Thin wrapper around `os.execute()` that provides no additional value.
Direct use of `lfs.mkdir()` or `os.execute()` is clearer and more explicit.

**Migration:**

```lua
-- OLD (deprecated):
lousy.util.mkdir("/path/to/directory")

-- NEW (option 1 - using lfs):
local lfs = require("lfs")
lfs.mkdir("/path/to/directory")

-- NEW (option 2 - using os.execute):
os.execute(string.format("mkdir -p %q", "/path/to/directory"))
```

**Timeline:** Deprecated in version `bce59c8`, will be removed in next major release.

---

### `lousy.util.eval(code)`

**Status:** Deprecated (will be removed in a future version)

**Reason:** Thin wrapper around `loadstring()` that provides no additional value.
Direct use of `load()` or `loadstring()` is clearer and more explicit.

**Migration:**

```lua
-- OLD (deprecated):
local result = lousy.util.eval("return 2 + 2")

-- NEW (option 1 - using load in Lua 5.2+):
local func = load("return 2 + 2")
local result = func()

-- NEW (option 2 - using loadstring in Lua 5.1/LuaJIT):
local func = assert(loadstring("return 2 + 2"))
local result = func()

-- NEW (option 3 - with error handling):
local func, err = load("return 2 + 2")
if func then
    local result = func()
else
    print("Error:", err)
end
```

**Timeline:** Deprecated in version `bce59c8`, will be removed in next major release.

**Security Note:** Be extremely careful when evaluating arbitrary code strings.
Only evaluate code from trusted sources.

---

### `lousy.util.checkfile(path)`

**Status:** Deprecated (will be removed in a future version)

**Reason:** Thin wrapper around `loadfile()` that provides no additional value.
Direct use of `loadfile()` with proper error handling is clearer and more explicit.

**Migration:**

```lua
-- OLD (deprecated):
local func_or_error = lousy.util.checkfile("/path/to/file.lua")
if type(func_or_error) == "function" then
    func_or_error()
else
    print("Error:", func_or_error)
end

-- NEW (using loadfile directly):
local func, err = loadfile("/path/to/file.lua")
if func then
    func()
else
    print("Error:", err)
end
```

**Timeline:** Deprecated in version `bce59c8`, will be removed in next major release.

---

## WebKitDOM API (Web Modules)

### All `page.document.*` Usage

**Status:** Deprecated (WebKit is removing this API)

**Reason:** WebKit has deprecated the entire WebKitDOM C API in favor of
JavaScript-based DOM manipulation using JavaScriptCore. This affects all web
modules that interact with page content.

**Deprecated Patterns:**
- `page.document.body`
- `element:query(selector)`
- `element:add_event_listener()`
- `element.attr.property`
- `element.rect.width`
- `element.tag_name`
- And all other `WebKitDOM` API usage

**Migration:**

See `JS_CALLBACK_PATTERN.md` for comprehensive migration guide.

**Example:**

```lua
-- OLD (deprecated WebKitDOM):
local doc = page.document
local buttons = doc.body:query("button")
for i, button in ipairs(buttons) do
    button:add_event_listener("click", true, function()
        handle_click(i)
    end)
end

-- NEW (JavaScript + Callbacks):
page:register_js_callback("button_clicked", function(index)
    handle_click(index)
end)

page:eval_js([[
    document.querySelectorAll('button').forEach(function(btn, index) {
        btn.addEventListener('click', function() {
            button_clicked(index + 1); // Lua uses 1-based indexing
        });
    });
]])
```

**Migrated Modules:**
- ✅ `error_page_wm.lua`
- ✅ `image_css_wm.lua`
- ✅ `webview_wm.lua`

**Pending Migration:**
- ⏳ `select_wm.lua`
- ⏳ `follow_wm.lua`
- ⏳ `formfiller_wm.lua`
- ⏳ `follow_selected_wm.lua`
- ⏳ `scroll.c`

**Timeline:** Already deprecated by WebKit, will be removed in future WebKit
versions. Migration should be completed before WebKit removes the API.

**References:**
- `JS_CALLBACK_PATTERN.md` - Complete migration guide
- `MIGRATION_STRATEGY.md` - Overall migration plan
- `COMPILATION_REPORT.md` - Analysis of deprecation warnings

---

## Implementation Notes

### Conditional Deprecation Warnings

The deprecation warnings in `lousy.util` functions (`mkdir`, `eval`, `checkfile`)
are conditionally enabled only when the `msg` module is available. This allows
`lousy.util` to be loaded in test environments without the C extensions, while
still showing warnings in normal luakit usage.

This is implemented using `pcall(require, "msg")` at module load time.

---

## How to Check if You're Using Deprecated Functions

### For lousy.util Functions

Search your configuration files:

```bash
# Check for deprecated lousy.util functions
grep -r "lousy\.util\.mkdir" ~/.config/luakit/
grep -r "lousy\.util\.eval" ~/.config/luakit/
grep -r "lousy\.util\.checkfile" ~/.config/luakit/
```

If you find any usage, follow the migration guide above.

### For WebKitDOM API

This only affects custom web modules (files ending in `_wm.lua`). If you've
written custom web modules that interact with page content, they likely use
WebKitDOM API and need migration.

Standard luakit modules are being migrated by the core developers.

---

## Deprecation Policy

### Warning Phase (Current)

- Deprecated functions continue to work
- Warning messages printed when functions are called
- Users should migrate to new APIs

### Removal Phase (Future)

- Deprecated functions will be removed entirely
- Code using deprecated functions will break
- Migration must be completed before this phase

### Timeline

- **Phase 1 (Isolated Features):** Completed
- **Phase 2 (Unused Functions):** Current phase
- **Phase 3-5:** Planned for future releases

Users will have at least one major release cycle to migrate their code.

---

## Getting Help

If you need help migrating your configuration or custom modules:

1. **Documentation:**
   - Read `JS_CALLBACK_PATTERN.md` for WebKitDOM migration
   - Read this file for lousy.util migration
   - Check `MIGRATION_STRATEGY.md` for overall plan

2. **Examples:**
   - Look at migrated modules: `error_page_wm.lua`, `image_css_wm.lua`, `webview_wm.lua`
   - Check existing code for patterns

3. **Community:**
   - Report issues at https://github.com/luakit/luakit/issues
   - Ask questions in discussions

---

## For Developers

### Adding New Deprecations

When deprecating a function:

1. Add `@deprecated` tag to documentation comment
2. Add `msg.warn()` calls with clear migration instructions
3. Keep original functionality intact (compatibility layer)
4. Add entry to this file with migration guide
5. Update relevant documentation

### Removing Deprecated Functions

Before removing a deprecated function:

1. Ensure at least one major release with deprecation warnings
2. Announce removal in release notes
3. Check for usage in standard modules
4. Remove function and compatibility layer
5. Update documentation

---

## Changelog

- **2026-01-18:** Added deprecation warnings to `lousy.util.mkdir()`,
  `lousy.util.eval()`, and `lousy.util.checkfile()`
- **2026-01-18:** Completed Phase 1 migration of isolated web modules
  (error_page_wm, image_css_wm, webview_wm)

---

**Note:** This file will be updated as more functions are deprecated or removed.
Always check the latest version for current deprecation status.
