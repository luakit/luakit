# GTK 4 Migration Plan for Luakit

## Executive Summary

This document outlines the comprehensive plan for migrating luakit from GTK 3 to GTK 4.

**Effort Estimate:** 80-120 hours (2-3 weeks full-time)
**Risk Level:** HIGH - Major breaking changes
**Benefit:** Future-proof for 5-10 years, modern APIs, better performance

---

## Current State Analysis

### Installed Libraries

```bash
GTK+:               3.24.41  → Need: GTK 4.x
WebKit2GTK:         2.50.4   → Need: webkitgtk-6.0
JavaScriptCoreGTK:  2.50.4   → Need: javascriptcoregtk-6.0
SQLite:             3.45.1   → No change
LuaJIT:             2.1.x    → No change
```

### GTK Usage in Codebase

**Total GTK API calls:** 294 across 20 C files

**Most GTK-heavy files:**
1. `widgets/label.c` - 28 calls
2. `widgets/notebook.c` - 24 calls
3. `widgets/window.c` - 24 calls
4. `widgets/scrolled.c` - 21 calls
5. `widgets/entry.c` - 18 calls
6. `clib/luakit.c` - 14 calls
7. `widgets/box.c` - 12 calls
8. Plus 13 more files with GTK usage

---

## Prerequisites

### Phase 0: Environment Setup

**Install GTK 4 and WebKitGTK 6.0:**

```bash
# Check distribution packages
sudo apt search libgtk-4-dev libwebkitgtk-6.0-dev  # Debian/Ubuntu
sudo dnf search gtk4-devel webkitgtk6.0-devel      # Fedora
sudo pacman -Ss gtk4 webkit2gtk-4.1                # Arch

# Install required packages (example for Debian/Ubuntu)
sudo apt install \
  libgtk-4-dev \
  libwebkitgtk-6.0-dev \
  libjavascriptcoregtk-6.0-dev
```

**Verify installation:**
```bash
pkg-config --modversion gtk4 webkitgtk-6.0
```

**Expected versions:**
- GTK 4: 4.10+ (latest stable)
- WebKitGTK 6.0: 2.42+ (API stable since 2.42)

---

## Breaking Changes Analysis

### 1. Main Loop and Application (CRITICAL)

**GTK 3:**
```c
gtk_init(&argc, &argv);
gtk_main();
gtk_main_quit();
```

**GTK 4:**
```c
GtkApplication *app = gtk_application_new("org.luakit.browser", 0);
g_signal_connect(app, "activate", G_CALLBACK(activate_cb), NULL);
g_application_run(G_APPLICATION(app), argc, argv);
```

**Impact:**
- `luakit.c` - Complete rewrite of main loop
- Must use `GtkApplication` or `GMainLoop`
- Event loop integration with Lua requires redesign

### 2. Widget Hierarchy Changes

**Removed in GTK 4:**
- `GtkBox` packing functions → Use `gtk_box_append()`, `gtk_box_prepend()`
- `gtk_container_add()` → Use widget-specific methods
- `gtk_widget_show_all()` → Widgets visible by default
- `gtk_widget_hide()` → Use `gtk_widget_set_visible(FALSE)`

**New patterns:**
```c
// GTK 3
gtk_container_add(GTK_CONTAINER(parent), child);
gtk_box_pack_start(GTK_BOX(box), child, expand, fill, padding);

// GTK 4
gtk_box_append(GTK_BOX(box), child);
gtk_widget_set_hexpand(child, expand);
gtk_widget_set_margin_start(child, padding);
```

### 3. Event Handling (MAJOR CHANGE)

**GTK 3:**
```c
g_signal_connect(widget, "button-press-event", G_CALLBACK(callback), data);
g_signal_connect(widget, "key-press-event", G_CALLBACK(callback), data);
```

**GTK 4:**
```c
// Use GtkEventController
GtkEventController *controller = gtk_event_controller_key_new();
g_signal_connect(controller, "key-pressed", G_CALLBACK(callback), data);
gtk_widget_add_controller(widget, controller);

// For mouse events
GtkGesture *gesture = gtk_gesture_click_new();
g_signal_connect(gesture, "pressed", G_CALLBACK(callback), data);
gtk_widget_add_controller(widget, GTK_EVENT_CONTROLLER(gesture));
```

**Impact:** ALL event handling code must be rewritten

### 4. CSS and Styling

**Changes:**
- CSS node names changed
- Some properties removed/renamed
- Theme integration changes

**Impact:** Custom CSS may need updates

### 5. Window Management

**GTK 3:**
```c
gtk_window_set_default_size(GTK_WINDOW(win), 800, 600);
gtk_window_set_position(GTK_WINDOW(win), GTK_WIN_POS_CENTER);
```

**GTK 4:**
```c
gtk_window_set_default_size(GTK_WINDOW(win), 800, 600);
// Position removed - window manager decides
```

### 6. Stock Items and Icons

**Removed:**
- All `GTK_STOCK_*` constants
- `gtk_image_new_from_stock()`

**Replacement:**
```c
// Use icon names
gtk_image_new_from_icon_name("document-open");
```

### 7. Tree and List Models

**Major redesign:**
- `GtkTreeView` still exists but discouraged
- New: `GtkListView`, `GtkColumnView`
- Different API for models

**Impact:** If luakit uses tree views, significant rewrite needed

---

## Migration Strategy

### Phase 1: Preparation (8-12 hours)

**1.1 Create Migration Branch**
```bash
git checkout -b gtk4-migration
```

**1.2 Document Current Behavior**
- Screenshot all UI components
- Document all keyboard shortcuts
- List all event handlers
- Capture current functionality

**1.3 Set Up Parallel Build System**
- Add GTK4 build option to Makefile
- Allow building both GTK3 and GTK4 versions
- Use conditional compilation where possible

**Example Makefile changes:**
```makefile
# Add GTK_VERSION variable
GTK_VERSION ?= 3

ifeq ($(GTK_VERSION),4)
    PKGS += gtk4
    PKGS += webkitgtk-6.0
    PKGS += javascriptcoregtk-6.0
    CFLAGS += -DGTK4
else
    PKGS += gtk+-3.0
    PKGS += webkit2gtk-4.1
    PKGS += javascriptcoregtk-4.1
endif
```

### Phase 2: Core Application (20-30 hours)

**2.1 Main Loop Migration** (`luakit.c`)
- Convert to `GtkApplication`
- Rewrite initialization
- Update event loop integration
- Test basic startup/shutdown

**2.2 Widget Infrastructure** (`widgets/common.c`, `clib/widget.c`)
- Update widget creation patterns
- Remove deprecated container functions
- Update show/hide logic
- Update parent-child relationships

**2.3 Window Management** (`widgets/window.c`)
- Update window creation
- Remove position-related code
- Update fullscreen handling
- Update resize logic

### Phase 3: Event System (25-35 hours)

**3.1 Keyboard Events**
- Create `GtkEventControllerKey` for all widgets needing keyboard input
- Migrate all `key-press-event` handlers
- Update key binding system
- Test all keyboard shortcuts

**3.2 Mouse Events**
- Create `GtkGestureClick` for click events
- Create `GtkGestureClick` for context menus (secondary click)
- Migrate all `button-press-event` handlers
- Test all mouse interactions

**3.3 Scroll Events**
- Create `GtkEventControllerScroll` for scrolling
- Migrate scroll handlers
- Test smooth scrolling

**3.4 Focus Events**
- Update focus-in/out event handling
- Test tab navigation

### Phase 4: Individual Widgets (15-25 hours)

**4.1 Simple Widgets**
- `widgets/label.c` - Update packing, alignment
- `widgets/image.c` - Remove stock item usage
- `widgets/spinner.c` - Minor updates
- `widgets/entry.c` - Update signals

**4.2 Container Widgets**
- `widgets/box.c` - Replace packing functions
- `widgets/paned.c` - Update API calls
- `widgets/stack.c` - Update switcher if needed
- `widgets/scrolled.c` - Update policy handling

**4.3 Complex Widgets**
- `widgets/notebook.c` - Update tab API
- `widgets/overlay.c` - Update child management
- `widgets/eventbox.c` - May be unnecessary in GTK4
- `widgets/drawing_area.c` - Update drawing API

### Phase 5: WebKitGTK Integration (10-15 hours)

**5.1 WebView Updates** (`widgets/webview.c`)
- Update to webkitgtk-6.0 API
- Check for any API changes
- Test web content rendering
- Verify JavaScript execution

**5.2 Web Extension** (`extension/*`)
- Update to webkit2gtk-web-extension-6.0
- Verify no API changes needed
- Test DOM access (should be unchanged)

### Phase 6: CSS and Theming (5-8 hours)

**6.1 CSS Updates**
- Review CSS for deprecated properties
- Test theme compatibility
- Update CSS node names if needed

**6.2 Visual Verification**
- Compare GTK3 vs GTK4 rendering
- Fix any layout issues
- Ensure consistent appearance

### Phase 7: Testing (15-20 hours)

**7.1 Functional Testing**
- Test all menu items
- Test all keyboard shortcuts
- Test all mouse interactions
- Test window management
- Test tab management
- Test downloads
- Test forms
- Test JavaScript
- Test Lua integration

**7.2 Integration Testing**
- Test session management
- Test bookmarks
- Test history
- Test extensions
- Test custom keybindings

**7.3 Performance Testing**
- Compare startup time
- Compare rendering performance
- Check memory usage
- Profile hot paths

### Phase 8: Documentation and Release (5-10 hours)

**8.1 Update Documentation**
- Update README build requirements
- Document GTK4-specific changes
- Update contributor guidelines

**8.2 Migration Guide for Users**
- Document configuration changes if any
- Note visual changes
- Provide troubleshooting guide

**8.3 Release Preparation**
- Tag release
- Write release notes
- Update changelog

---

## Risk Mitigation

### High-Risk Areas

**1. Main Loop Changes**
- **Risk:** Breaking Lua integration
- **Mitigation:** Extensive testing of Lua event loop integration
- **Fallback:** Revert to GMainLoop if GtkApplication causes issues

**2. Event Handling**
- **Risk:** Missing event handlers, broken keyboard shortcuts
- **Mitigation:** Comprehensive event handler mapping document
- **Testing:** Automated keyboard/mouse event tests

**3. WebKitGTK 6.0 API Changes**
- **Risk:** Unexpected API differences
- **Mitigation:** Early testing of webkitgtk-6.0
- **Fallback:** Stay on webkit2gtk-4.1 until ready

### Testing Strategy

**Unit Testing:**
- Test each widget in isolation
- Verify Lua bindings work correctly
- Check event propagation

**Integration Testing:**
- Full end-to-end user workflows
- Session persistence
- Extension loading
- Multi-window scenarios

**Visual Regression Testing:**
- Screenshot comparison (GTK3 vs GTK4)
- Manual review of all UI components
- Theme testing (light/dark)

---

## Timeline Estimate

| Phase | Task | Hours | Dependencies |
|-------|------|-------|--------------|
| 0 | Environment Setup | 2-4 | None |
| 1 | Preparation | 8-12 | Phase 0 |
| 2 | Core Application | 20-30 | Phase 1 |
| 3 | Event System | 25-35 | Phase 2 |
| 4 | Widgets | 15-25 | Phase 2 |
| 5 | WebKitGTK | 10-15 | Phase 2, 4 |
| 6 | CSS/Theming | 5-8 | Phase 4, 5 |
| 7 | Testing | 15-20 | Phase 2-6 |
| 8 | Documentation | 5-10 | Phase 7 |
| **TOTAL** | **105-159 hours** | **(2.5-4 weeks)** | |

**Optimistic:** 105 hours (2.5 weeks)
**Realistic:** 130 hours (3+ weeks)
**Pessimistic:** 159 hours (4 weeks)

---

## Dependency Graph

```
Phase 0 (Setup)
  ↓
Phase 1 (Prep) ←─────────────┐
  ↓                           │
Phase 2 (Core) ←─────────┐   │
  ↓         ↓              │   │
Phase 3   Phase 4        │   │
(Events)  (Widgets) ←────┘   │
  ↓         ↓                 │
Phase 5 (WebKit) ←───────────┘
  ↓
Phase 6 (CSS)
  ↓
Phase 7 (Testing)
  ↓
Phase 8 (Docs)
```

**Critical Path:** Phase 0 → 1 → 2 → 3 → 5 → 7 → 8

---

## Success Criteria

### Must Have ✅

- [ ] Compiles without errors on GTK 4
- [ ] All widgets render correctly
- [ ] All keyboard shortcuts work
- [ ] All mouse interactions work
- [ ] Web content renders correctly
- [ ] Lua bindings functional
- [ ] No regressions in core functionality
- [ ] All tests pass

### Should Have ✅

- [ ] Performance equal or better than GTK 3
- [ ] Visual appearance consistent with GTK 3
- [ ] CSS theming works
- [ ] Session management works
- [ ] Extensions load correctly

### Nice to Have ✅

- [ ] Better Wayland support
- [ ] Improved performance
- [ ] Modern GTK4 features utilized
- [ ] Smoother animations

---

## Rollback Plan

If migration encounters critical issues:

**Option A: Revert**
- Keep GTK 3 version as default
- Continue GTK 4 work on feature branch
- Re-evaluate approach

**Option B: Dual-Track**
- Maintain both GTK 3 and GTK 4 versions
- Build-time selection via Makefile
- Gradual transition as GTK 4 version matures

**Option C: Pause**
- Stop GTK 4 work
- Wait for GTK 4 ecosystem to mature
- Revisit in 6-12 months

---

## Next Steps

### Immediate Actions

**1. Decision Point**
- Confirm GTK 4 migration is desired
- Allocate time for migration work
- Set target completion date

**2. Environment Setup**
- Install GTK 4 development packages
- Install webkitgtk-6.0
- Verify build tools

**3. Create Migration Branch**
```bash
git checkout -b gtk4-migration
git push -u origin gtk4-migration
```

**4. Begin Phase 1**
- Document current behavior
- Set up parallel build system
- Create migration checklist

---

## Resources

### Official Documentation

- [GTK 4 Migration Guide](https://docs.gtk.org/gtk4/migrating-3to4.html)
- [GTK 4 API Reference](https://docs.gtk.org/gtk4/)
- [WebKitGTK 6.0 API](https://webkitgtk.org/reference/webkit2gtk/stable/index.html)

### Example Migrations

- [GNOME Apps Migration](https://gitlab.gnome.org/)
- [Elementary OS Apps](https://github.com/elementary/)
- Community blog posts and guides

### Support Channels

- GTK Discourse: https://discourse.gnome.org/c/platform/
- WebKitGTK Mailing List
- Stack Overflow (gtk4 tag)

---

## Conclusion

GTK 4 migration is a **significant but achievable undertaking**. With proper planning, incremental approach, and comprehensive testing, luakit can successfully migrate to the modern GTK 4 ecosystem.

**Recommended Approach:**
1. ✅ Complete environment setup
2. ✅ Start with small, isolated components
3. ✅ Test thoroughly at each phase
4. ✅ Maintain fallback to GTK 3 during transition
5. ✅ Release GTK 4 version when stable

**Timeline:** 3-4 weeks of focused effort
**Benefit:** Future-proof luakit for the next 5-10 years

---

**Status:** Ready to begin
**Created:** 2026-01-18
**Author:** Migration Planning Assistant
