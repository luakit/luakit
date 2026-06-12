@name Process and IPC Architecture
# Process and IPC Architecture

This document describes the multi-process architecture of Luakit (under GTK4 and WebKitGTK 6.0) and how the custom Unix IPC channel coexists with WebKit's internal communication.

## Architecture Overview

Luakit is built on top of WebKitGTK, which uses a multi-process architecture to separate different concerns for security, stability, and resource management.

1. **UI Process (Main)**:
   - This is the main application process that runs the user interface, window management, and GTK widgets.
   - It runs the main Lua VM (`common.L`) where user configuration (`rc.lua`) and UI-facing modules are loaded.
   - It instantiates `WebKitWebView` objects, representing browser tabs.

2. **Web Content Processes (Sandboxed)**:
   - These are separate sandboxed processes spawned by WebKit to render web pages and run JavaScript.
   - Each Web Process loads our Web Process Extension (`luakit.so`).
   - The extension runs a separate Lua VM (`common.L`) dedicated to web-process operations, DOM traversal, and page-level scripting.
   - A single Web Process can host one or multiple `WebKitWebPage` instances (for example, tabs sharing the same origin to optimize memory).

## Communication Channels

Luakit relies on two separate IPC channels to link the UI and Web processes:

*   **WebKit Internal IPC**: Used automatically by WebKitGTK to synchronize state and properties (such as the `page-id`) between `WebKitWebView` and `WebKitWebPage`.
*   **Custom Unix Sockets (Luakit IPC)**: A dedicated Unix domain socket connection established between the UI process and each Web Process's extension. This channel passes serialized Lua structures for custom page-specific actions (e.g., executing scripts, getting DOM elements for Follow mode, scroll actions, and form filling).

## Process Swap & Synchronization

WebKitGTK 6.0 uses **Process Swap on Navigation (PSON)**. When navigating to a cross-origin URI, WebKit spawns a new Web Process:

1. A new Web Process is launched, and its extension connects to the UI process socket.
2. The web process extension triggers a `page-created` signal for the new page.
3. Because process creation and socket connections are asynchronous, the Web Process might notify the UI process before the UI process's `WebKitWebView` has committed the navigation and updated its `page-id` property.
4. The UI process handles this race condition by buffering incoming socket connections in a pending registry until the `notify::page-id` property change event fires on the webview, at which point the connection is completed.
