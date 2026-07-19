@name Cross-Origin Iframe Link Hinting (Follow Mode)
# Cross-Origin Iframe Link Hinting (Follow Mode)

This document describes the technical architecture and implementation supporting link hinting (`follow` mode) and form filling inside cross-origin iframes within Luakit.

---

## 1. Problem Statement

Luakit's original `follow` mode implementation assumed a single Web Process per tab and used recursive DOM element traversal starting from the main document (`page.document.body`). When a webpage contains cross-origin iframes, two problems arise:

1. **JavaScript Security Restrictions**: Browsers enforce same-origin policies on JavaScript execution contexts. The main frame's Web Extension cannot inspect or query `iframe.contentDocument` for cross-origin frames via standard JavaScript/DOM properties.
2. **IPC Endpoint Registration**: Under WebKitGTK's multi-process site isolation (where cross-origin iframes load in separate Web Processes), subframe connections were previously overwriting the main webview's primary IPC endpoint (`d->ipc`).

---

## 2. Architecture & Implementation

Luakit handles both **Single-Process (Same-Process Subframes)** and **Multi-Process Site-Isolated Subframes** seamlessly:

```
                    +------------------------+
                    |    UI Process (C)      |
                    |                        |
                    |  webview_data_t        |
                    |  - d->ipc (main)       |
                    |  - d->subframe_ipcs    |
                    +------------------------+
                     /          |           \
        (IPC Socket) /           |            \ (IPC Socket)
                    /            |             \
     +-----------------+ +---------------+ +---------------+
     |   Main Frame    | | Same-Origin   | | Cross-Origin  |
     |  Web Extension  | | Subframe      | | Subframe      |
     | (Web Process 1) | | (Web Process 1| | (Web Process 2) |
     +-----------------+ +---------------+ +---------------+
```

### 2.1 Multi-Process IPC Management (`widgets/webview.c` & `extension/ipc.c`)
- **Main Frame Detection**: Subframe processes are correctly identified using `webkit_frame_is_main_frame(frame)`.
- **Subframe Endpoints**: Subframe connections register via `webview_add_subframe_endpoint` into `d->subframe_ipcs` instead of overwriting the main endpoint `d->ipc`.
- **Signal Broadcasting**: `webview_send_lua_to_subframes` broadcasts signals (e.g. `init_follow`) to all registered subframe processes.

### 2.2 Native Frame Tracking & `page:get_frames()` (`extension/luajs.c` & `extension/clib/page.c`)
In environments where Site Isolation is not active, cross-origin iframes execute in the same Web Process as the main page:
- **`GPtrArray` Frame Tracking**: The Web Extension listens to `"window-object-cleared"` across all script worlds and maintains a list of active `WebKitFrame` instances on the `WebKitWebPage` GObject (`luakit-frames`), with weak notifies (`g_object_weak_ref`) for automatic unref cleanup.
- **`page:get_frames()` API**: C code in the extension accesses each frame's isolated `JSCContext` directly via `webkit_frame_get_js_context_for_script_world`. Because C extension execution bypasses JavaScript same-origin restrictions, it retrieves the `document` node of every frame and exposes them to Lua as a list of `dom_document` wrappers.

### 2.3 Element Scanning (`lib/select_wm.lua` & `lib/formfiller_wm.lua`)
- `select.scan` and `formfiller_wm` query elements across all frame documents returned by `page:get_frames()`.
- Each element's bounding box is checked for viewport visibility, and hints are generated for all visible elements across main and child frames.

---

## 3. Element Click & Focus Dispatch

- **Direct Method Invocation**: For elements in cross-origin frames, calling standard page JS wrappers across contexts may fail. Luakit uses `element:click()` (which invokes `jsc_value_object_invoke_method(elem, "click")` directly within the element's own execution context), ensuring cross-origin click events execute safely.
- **Target `_blank` Handling**: `click_a_target_blank` signals bypass in-process navigation and request the UI process to open new tabs cleanly.
