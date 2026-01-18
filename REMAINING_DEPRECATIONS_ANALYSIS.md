# Remaining Deprecation Warnings Analysis

**Date:** 2026-01-18
**Total Warnings:** 81
**Status:** Ready for Next Phase

---

## Breakdown by File

| File | Warnings | Percentage |
|------|----------|------------|
| extension/clib/dom_element.c | 64 | 79% |
| extension/clib/dom_document.c | 10 | 12% |
| Other files (ipc.c, luajs.c, scroll.c) | 7 | 9% |

---

## Deprecation Categories

### 1. WebKit Frame API (9 warnings) - **EASY WIN!** ✅

**API:** `webkit_web_page_get_main_frame()` - 9 occurrences

**Files:**
- extension/ipc.c (1)
- extension/luajs.c (1)
- extension/scroll.c (2)
- extension/clib/dom_document.c (2)
- extension/clib/dom_element.c (3)

**Status:** NOT WebKitDOM - This is a newer WebKit API deprecation
**Difficulty:** LOW - Should have a direct replacement
**Priority:** HIGH - Easy win, affects multiple files

---

### 2. Type Checking Macros (24 warnings) - Infrastructure

**APIs:**
- `webkit_dom_element_get_type()` - 7 occurrences
- `webkit_dom_node_get_type()` - 5 occurrences
- `webkit_dom_keyboard_event_get_type()` - 6 occurrences
- `webkit_dom_mouse_event_get_type()` - 2 occurrences
- `webkit_dom_event_target_get_type()` - 3 occurrences
- `webkit_dom_ui_event_get_type()` - 1 occurrence

**Used for:** `WEBKIT_DOM_IS_*` type checking macros
**Status:** Infrastructure - used by all helpers
**Difficulty:** MEDIUM - Need to find alternative type checking
**Priority:** MEDIUM - Infrastructure code

---

### 3. Event System (20 warnings) - **ARCHITECTURAL BOUNDARY**

**Event Listener APIs (6):**
- `webkit_dom_event_target_add_event_listener()` - 2
- `webkit_dom_event_target_remove_event_listener()` - 4

**Event Property APIs (14):**
- `webkit_dom_event_get_src_element()` - 1
- `webkit_dom_event_get_event_type()` - 1
- `webkit_dom_event_get_event_phase()` - 1
- `webkit_dom_event_prevent_default()` - 1
- `webkit_dom_event_stop_propagation()` - 1
- `webkit_dom_keyboard_event_get_*()` - 5 (key_identifier, alt_key, ctrl_key, meta_key, shift_key)
- `webkit_dom_mouse_event_get_button()` - 1
- `webkit_dom_ui_event_get_char_code()` - 1
- Event target getting - 2

**Status:** Requires bidirectional JavaScript↔Lua bridge
**Difficulty:** HIGH - Architectural changes needed
**Priority:** LOW - Complex, lower ROI

---

### 4. Navigation Properties (6 warnings) - **ARCHITECTURAL BOUNDARY**

**APIs:**
- `webkit_dom_node_get_parent_node()` - 2
- `webkit_dom_element_get_previous_element_sibling()` - 2
- `webkit_dom_element_get_next_element_sibling()` - 1
- `webkit_dom_element_get_first_element_child()` - 1
- `webkit_dom_element_get_last_element_child()` - 1

**Status:** Requires returning new dom_element objects (needs pointers)
**Difficulty:** HIGH - Architectural changes needed
**Priority:** MEDIUM - Useful but complex

---

### 5. Query Method (3 warnings) - **ARCHITECTURAL BOUNDARY**

**APIs:**
- `webkit_dom_element_query_selector_all()` - 1
- `webkit_dom_node_list_get_length()` - 1
- `webkit_dom_node_list_item()` - 1

**Status:** Returns array of elements (needs pointers)
**Difficulty:** HIGH - Architectural changes needed
**Priority:** HIGH - Used by follow_wm.lua (critical feature)

---

### 6. Document APIs (8 warnings) - **MIXED DIFFICULTY**

**APIs:**
- `webkit_web_page_get_dom_document()` - 3 (Infrastructure)
- `webkit_dom_node_get_owner_document()` - 3 (Infrastructure)
- `webkit_dom_document_get_body()` - 1 (Returns element)
- `webkit_dom_document_create_element()` - 1 (Returns element)
- `webkit_dom_document_element_from_point()` - 1 (Returns element)
- `webkit_dom_document_get_type()` - 1 (Type checking)

**Status:** Mixed - some are infrastructure, some return elements
**Difficulty:** MEDIUM-HIGH
**Priority:** MEDIUM

---

### 7. Frame/IFrame Content (4 warnings)

**APIs:**
- `webkit_dom_html_frame_element_get_type()` - 2
- `webkit_dom_html_frame_element_get_content_document()` - 1
- `webkit_dom_html_iframe_element_get_type()` - 2
- `webkit_dom_html_iframe_element_get_content_document()` - 1

**Status:** Frame content access
**Difficulty:** MEDIUM
**Priority:** LOW - Less commonly used

---

### 8. Miscellaneous (7 warnings)

**APIs:**
- `webkit_dom_element_get_tag_name()` - 1 (Used in selector generation)
- `webkit_dom_element_set_attribute()` - 1 (Used in create_element)
- `webkit_dom_html_element_set_inner_text()` - 1 (Used in create_element)
- `webkit_dom_html_element_get_type()` - 1 (Type checking)

**Status:** Various
**Difficulty:** LOW-MEDIUM
**Priority:** MEDIUM

---

## Recommended Attack Plan

### Phase 7.1: Low-Hanging Fruit (Easy Wins) ✅

**Target:** 9-15 warnings eliminated
**Effort:** 2-3 hours
**Risk:** LOW

**Tasks:**
1. ✅ **webkit_web_page_get_main_frame()** (9 warnings)
   - Research replacement API
   - Update all 7 call sites
   - Verify builds and runs

2. **Selector generation optimization** (2-4 warnings)
   - Cache selectors where possible
   - Reduce redundant calls in dom_element_selector()

**Expected Result:** 81 → 70-75 warnings

---

### Phase 7.2: Document APIs (Optional)

**Target:** 5-8 warnings eliminated
**Effort:** 3-4 hours
**Risk:** MEDIUM

**Tasks:**
1. Migrate simple document properties
2. Keep element-returning methods (body, create_element) for later

**Expected Result:** 70-75 → 65-70 warnings

---

### Phase 7.3: Navigation Properties (Future)

**Target:** 6 warnings eliminated
**Effort:** 8-12 hours
**Risk:** HIGH - Requires architectural changes

**Tasks:**
1. Redesign element object creation
2. Implement JavaScript-based navigation
3. Update Lua bindings

**Expected Result:** 65-70 → 60-65 warnings

---

### Phase 7.4: Event System (Future)

**Target:** 20 warnings eliminated
**Effort:** 20-30 hours
**Risk:** VERY HIGH - Major architectural changes

**Tasks:**
1. Design JavaScript↔Lua event bridge
2. Implement JavaScript event handlers
3. Port all event listeners
4. Extensive testing required

**Expected Result:** 60-65 → 40-45 warnings

---

## Immediate Next Step

**START WITH:** webkit_web_page_get_main_frame() migration

This is:
- ✅ Not WebKitDOM related
- ✅ Should have a direct replacement
- ✅ Easy to verify
- ✅ Affects 9 warnings across 7 files
- ✅ Low risk

Let's investigate the replacement API and tackle this first!

---

**Document Created:** 2026-01-18
**Author:** Claude
**Status:** Analysis Complete - Ready to Proceed
