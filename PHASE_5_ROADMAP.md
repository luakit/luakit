# Phase 5 Migration Roadmap

**Date:** 2026-01-18
**Status:** Planning
**Estimated Effort:** 4-6 weeks of focused development
**Risk Level:** ⭐⭐⭐⭐ High (affects core user features)

## Executive Summary

Phase 5 represents the final and most complex phase of the luakit WebKitDOM API migration. This phase migrates the core DOM manipulation infrastructure (dom_element.c, dom_document.c) and the three critical web modules that provide link following and form filling functionality.

**What's at Stake:**
- Link following (f key) - core browsing feature
- Form filling - password management and autofill
- Element selection - underlies both features above

**Complexity:**
- dom_element.c: 991 lines, 31 functions, ~180 deprecation warnings
- dom_document.c: 210 lines, ~13 warnings
- 3 interconnected Lua modules: select_wm.lua, follow_wm.lua, formfiller_wm.lua

## Progress To Date

### Phases 1-4 Complete ✅

| Phase | Status | Warnings Reduced | Key Accomplishment |
|-------|--------|------------------|-------------------|
| 1 | ✅ Complete | 0 | Migrated 3 isolated web modules to JavaScript |
| 2 | ✅ Complete | 0 | Deprecated 3 unused utility functions |
| 3 | ✅ Complete | 0 | Migrated 2 utility functions to inline implementations |
| 4 | ✅ Complete | 1 | **Migrated scroll.c (eliminated 16/18 warnings)** |

**Total Progress:** 215 → 214 deprecation warnings (1 eliminated)

### What Phases 1-4 Accomplished

1. **Established migration patterns** - Proven approach for WebKitDOM→JavaScript
2. **Built infrastructure** - JavaScript callback system in place
3. **Zero regressions** - All tests passing, functionality intact
4. **Documented approach** - Clear patterns for future work

## Phase 5 Architecture

### Current Architecture (WebKitDOM-based)

```
Lua Module Layer:
  select_wm.lua  ←→  follow_wm.lua  ←→  formfiller_wm.lua
       ↓                  ↓                      ↓
C DOM Layer:
  dom_element.c (991 lines, 31 functions)
  dom_document.c (210 lines)
       ↓
WebKitDOM API (DEPRECATED)
```

### Target Architecture (JavaScript-based)

```
Lua Module Layer:
  select_wm.lua  ←→  follow_wm.lua  ←→  formfiller_wm.lua
       ↓                  ↓                      ↓
C Wrapper Layer:
  dom_element.c (thin wrapper)
  dom_document.c (thin wrapper)
       ↓
JavaScriptCore API
       ↓
JavaScript DOM APIs
```

## Phase 5 Components

### 5.1 dom_element.c Migration

**Lines:** 991
**Functions:** 31
**Deprecation Warnings:** ~180

**Most Critical Properties** (used by Phase 5 modules):
1. `element.tag_name` - Get element tag (A, INPUT, FORM, etc.)
2. `element.attr` - Get/set attributes (href, type, value, etc.)
3. `element.rect` - Get element bounding box for positioning
4. `element.style` - Get/set CSS styles for visibility
5. `element.text_content` - Get element text
6. `element.parent` - Navigate DOM tree
7. `element.query()` - Find child elements

**Migration Strategy:**
- **Keep:** Lua API surface (backward compatible)
- **Replace:** WebKitDOM calls with JavaScript execution
- **Pattern:** Use jsc_context_evaluate() to run JavaScript, return results to Lua

**Example Migration:**

```c
/* OLD (WebKitDOM): */
PS_CASE(TAG_NAME, webkit_dom_element_get_tag_name(elem))

/* NEW (JavaScript): */
case L_TK_TAG_NAME: {
    JSCContext *ctx = dom_element_get_js_context(element);
    JSCValue *js_elem = dom_element_js_ref(page, element);
    JSCValue *result = jsc_value_object_get_property(js_elem, "tagName");
    const char *tag = jsc_value_to_string(result);
    lua_pushstring(L, tag);
    g_object_unref(result);
    g_object_unref(js_elem);
    g_object_unref(ctx);
    return 1;
}
```

**Estimated Effort:** 3 weeks
- Week 1: Migrate properties (tag_name, attr, style, rect)
- Week 2: Migrate methods (query, click, focus, append, remove)
- Week 3: Migrate navigation (parent, children, siblings)

### 5.2 dom_document.c Migration

**Lines:** 210
**Functions:** 6
**Deprecation Warnings:** ~13

**Functions to Migrate:**
1. `create_element(tag, attrs, text)` - Used by select_wm for overlays
2. `element_from_point(x, y)` - Used by follow_wm for link detection
3. `get_body()` - Get document body element
4. `window.scroll_x/y` - Already available via page API (can skip)

**Migration Strategy:**
- Use JavaScript `document.createElement()` and `document.elementFromPoint()`
- Return dom_element wrappers to maintain Lua API compatibility

**Estimated Effort:** 1 week

### 5.3 Lua Module Updates

**Modules:** select_wm.lua, follow_wm.lua, formfiller_wm.lua
**Changes:** Minimal to none (if C API stays compatible)

**Testing Required:**
- Link following (f, F, ;o, ;t, etc.)
- Form detection and filling
- Element selection and hints
- Tab/window opening
- Click/focus behavior

**Estimated Effort:** 1 week (testing and fixes)

## Migration Approach

### Option A: Incremental Migration (Recommended)

Migrate dom_element.c incrementally, testing at each step:

**Week 1: Core Properties**
- Day 1-2: Migrate tag_name, text_content, inner_html
- Day 3-4: Migrate attr table (getAttribute/setAttribute)
- Day 5: Test with simple follow mode use cases

**Week 2: Layout Properties**
- Day 1-2: Migrate rect property (getBoundingClientRect)
- Day 3-4: Migrate style property
- Day 5: Test with select_wm overlays

**Week 3: Methods & Navigation**
- Day 1-2: Migrate query(), click(), focus()
- Day 3-4: Migrate parent, children, siblings
- Day 5: Integration testing

**Week 4: dom_document & Integration**
- Day 1-2: Migrate create_element, element_from_point
- Day 3-5: Full integration testing, bug fixes

**Week 5: Polish & Documentation**
- Day 1-2: Performance optimization
- Day 3-4: Documentation updates
- Day 5: Final testing

**Week 6: Buffer** (for unexpected issues)

### Option B: Atomic Migration

Migrate everything at once, test at the end:
- Higher risk (all or nothing)
- Faster if successful
- Harder to debug issues

**Recommendation:** Option A (Incremental)

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking follow mode | Medium | Critical | Extensive testing at each step |
| Performance regression | Low | Medium | Benchmark before/after |
| Memory leaks | Low | High | Valgrind testing |
| Race conditions | Low | Medium | Test edge cases |
| Breaking user configs | Low | High | Maintain API compatibility |

### User Impact Risks

**If Phase 5 Goes Wrong:**
- Link following broken = major usability issue
- Form filling broken = password management compromised
- Need rollback capability

**Mitigation:**
- Test thoroughly at each step
- Keep old code in version control
- Feature flag for easy rollback
- Beta testing period before release

## Testing Strategy

### Unit Testing

Test each migrated function in isolation:
```lua
-- Test tag_name
local elem = doc:create_element("a")
assert(elem.tag_name == "A")

-- Test attr
elem.attr.href = "https://example.com"
assert(elem.attr.href == "https://example.com")

-- Test rect
local rect = elem.rect
assert(rect.width > 0)
```

### Integration Testing

Test complete workflows:
1. Open page with links
2. Press 'f' to enter follow mode
3. Verify hints appear
4. Select link
5. Verify navigation works

### Performance Testing

Benchmark critical operations:
- Time to render hints (should be < 100ms)
- Memory usage (should not increase)
- Page load impact (should be minimal)

### Regression Testing

Run full test suite:
```bash
gmake run-tests
```

All existing tests must pass.

## Success Criteria

### Must Have ✅
- [ ] All dom_element properties migrated
- [ ] All dom_document functions migrated
- [ ] Follow mode works (f, F, ;o, ;t)
- [ ] Form filling works
- [ ] All tests passing
- [ ] Zero regressions

### Should Have ✅
- [ ] Performance within 10% of original
- [ ] Memory usage stable
- [ ] Deprecation warnings: 214 → ~20 (eliminate ~194)
- [ ] Code cleaner and more maintainable

### Nice to Have ✨
- [ ] Performance improved over original
- [ ] Better error messages
- [ ] Enhanced debugging capabilities

## Estimated Timeline

**Conservative Estimate:** 6 weeks
- Week 1: Core properties
- Week 2: Layout properties
- Week 3: Methods & navigation
- Week 4: dom_document & integration
- Week 5: Polish & documentation
- Week 6: Buffer for unexpected issues

**Optimistic Estimate:** 4 weeks
- Assumes no major blockers
- Minimal debugging needed
- Good test coverage catches issues early

**Realistic Estimate:** 5 weeks

## Next Steps

### Immediate Actions

1. **Create feature branch** for Phase 5 work
2. **Set up testing environment** for frequent testing
3. **Begin with tag_name migration** (simplest property)
4. **Test incrementally** after each property

### Phase 5 Kickoff Checklist

- [ ] Review this roadmap
- [ ] Agree on timeline
- [ ] Set up testing workflow
- [ ] Create Phase 5 branch
- [ ] Begin with 5.1 (dom_element properties)

## Resources

### Documentation
- MIGRATION_STRATEGY.md - Overall strategy
- JS_CALLBACK_PATTERN.md - Callback infrastructure
- COMPILATION_REPORT.md - Deprecation analysis

### Key Files
- extension/clib/dom_element.c - Main target (991 lines)
- extension/clib/dom_document.c - Secondary target (210 lines)
- lib/select_wm.lua - Core selection module
- lib/follow_wm.lua - Link following
- lib/formfiller_wm.lua - Form filling

### Testing
- tests/ - Test suite
- gmake run-tests - Run all tests

## Conclusion

Phase 5 is the culmination of the migration effort. It's complex but achievable with:
- Incremental approach
- Frequent testing
- Clear success criteria
- Adequate time buffer

**Recommendation:** Proceed with Option A (Incremental Migration) over 5-6 weeks.

---

**Document Version:** 1.0
**Created:** 2026-01-18
**Author:** Claude (Migration AI Assistant)
**Status:** Roadmap - Awaiting approval to begin
