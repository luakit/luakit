/*
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "extension/clib/dom_element.h"
#include "extension/clib/dom_document.h"
#include "common/luauniq.h"
#include "extension/extension.h"
#include "common/tokenize.h"

#define REG_KEY "luakit.uniq.registry.dom_element"

static lua_class_t dom_element_class;

LUA_DOM_ELEMENT_FUNCS(dom_element_class, dom_element_t, dom_element);

static guint64
js_value_get_unique_id(JSCValue *val)
{
    JSCContext *ctx = jsc_value_get_context(val);
    JSCValue *js_id = jsc_value_object_get_property(val, "__luakit_id");
    guint64 id;
    if (jsc_value_is_undefined(js_id)) {
        static guint64 next_id = 1;
        id = next_id++;
        JSCValue *new_id = jsc_value_new_number(ctx, id);
        jsc_value_object_set_property(val, "__luakit_id", new_id);
        g_object_unref(new_id);
    } else {
        id = (guint64)jsc_value_to_double(js_id);
    }
    g_object_unref(js_id);
    return id;
}

static dom_element_t*
luaH_check_dom_element(lua_State *L, gint udx)
{
    dom_element_t *element = luaH_checkudata(L, udx, &dom_element_class);
    if (!element->element)
        luaL_argerror(L, udx, "DOM element no longer valid");
    return element;
}

static gint
luaH_dom_element_gc(lua_State *L)
{
    dom_element_t *element = luaH_toudata(L, 1, &dom_element_class);
    if (element) {
        if (element->element) {
            guint64 id = js_value_get_unique_id(element->element);
            luaH_uniq_del_ptr(L, REG_KEY, (void*)(uintptr_t)id);
            g_object_unref(element->element);
            element->element = NULL;
        }
        if (element->dom_events) {
            signal_destroy(element->dom_events);
            element->dom_events = NULL;
        }
    }
    return luaH_object_gc(L);
}

gint
luaH_dom_element_from_node(lua_State *L, JSCValue* node)
{
    if (!node || jsc_value_is_null(node) || jsc_value_is_undefined(node)) {
        lua_pushnil(L);
        return 1;
    }

    guint64 id = js_value_get_unique_id(node);
    void *ptr = (void*)(uintptr_t)id;

    if (luaH_uniq_get_ptr(L, REG_KEY, ptr))
        return 1;

    dom_element_t *element = dom_element_new(L);
    element->element = g_object_ref(node);

    luaH_uniq_add_ptr(L, REG_KEY, ptr, -1);
    return 1;
}

dom_element_t *
luaH_to_dom_element(lua_State *L, gint idx)
{
    return luaH_toudata(L, idx, &dom_element_class);
}

JSCValue *
dom_element_js_ref(page_t *UNUSED(page), dom_element_t *element)
{
    return g_object_ref(element->element);
}

static gint
luaH_dom_element_query(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *query = luaL_checkstring(L, 2);

    JSCValue *nodes = jsc_value_object_invoke_method(element->element, "querySelectorAll", G_TYPE_STRING, query, G_TYPE_NONE);
    JSCValue *len_val = jsc_value_object_get_property(nodes, "length");
    gint n = jsc_value_to_int32(len_val);
    g_object_unref(len_val);

    lua_createtable(L, n, 0);
    for (gint i = 0; i < n; i++) {
        JSCValue *node = jsc_value_object_get_property_at_index(nodes, i);
        luaH_dom_element_from_node(L, node);
        g_object_unref(node);
        lua_rawseti(L, 3, i + 1);
    }
    g_object_unref(nodes);

    return 1;
}

static gint
luaH_dom_element_append(lua_State *L)
{
    dom_element_t *parent = luaH_check_dom_element(L, 1),
                  *child = luaH_check_dom_element(L, 2);
    JSCValue *ret = jsc_value_object_invoke_method(parent->element, "appendChild", JSC_TYPE_VALUE, child->element, G_TYPE_NONE);
    if (ret) g_object_unref(ret);
    return 0;
}

static gint
luaH_dom_element_remove(lua_State *L)
{
    dom_element_t *element = luaH_toudata(L, 1, &dom_element_class);
    if (element && element->element) {
        JSCValue *ret = jsc_value_object_invoke_method(element->element, "remove", G_TYPE_NONE);
        if (ret) g_object_unref(ret);
    }
    return 0;
}

static gint
luaH_dom_element_rect_index(lua_State *L)
{
    dom_element_t *element = luaH_toudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    JSCContext *ctx = jsc_value_get_context(element->element);
    double val = 0.0;

    if (token == L_TK_WIDTH) {
        JSCValue *val_obj = jsc_value_object_get_property(element->element, "offsetWidth");
        val = jsc_value_to_double(val_obj);
        g_object_unref(val_obj);
    } else if (token == L_TK_HEIGHT) {
        JSCValue *val_obj = jsc_value_object_get_property(element->element, "offsetHeight");
        val = jsc_value_to_double(val_obj);
        g_object_unref(val_obj);
    } else if (token == L_TK_LEFT || token == L_TK_TOP) {
        JSCValue *fn = jsc_context_evaluate_with_source_uri(ctx,
            "(function(elem) {\n"
            "  var r = elem.getBoundingClientRect();\n"
            "  return { left: r.left + window.scrollX, top: r.top + window.scrollY };\n"
            "})", -1, NULL, 1);
        JSCValue *res = jsc_value_function_call(fn, JSC_TYPE_VALUE, JSC_TYPE_VALUE, element->element, G_TYPE_NONE);
        JSCValue *prop_val = jsc_value_object_get_property(res, token == L_TK_LEFT ? "left" : "top");
        val = jsc_value_to_double(prop_val);
        g_object_unref(prop_val);
        g_object_unref(res);
        g_object_unref(fn);
    } else {
        return 0;
    }

    lua_pushnumber(L, val);
    return 1;
}

static gint
luaH_dom_element_push_rect_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_rect_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_attribute_index(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *name = luaL_checkstring(L, 2);
    JSCValue *res = jsc_value_object_invoke_method(element->element, "getAttribute", G_TYPE_STRING, name, G_TYPE_NONE);
    if (jsc_value_is_null(res) || jsc_value_is_undefined(res)) {
        lua_pushnil(L);
    } else {
        gchar *str = jsc_value_to_string(res);
        lua_pushstring(L, str);
        g_free(str);
    }
    g_object_unref(res);
    return 1;
}

static gint
luaH_dom_element_attribute_newindex(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *attr = luaL_checkstring(L, 2);
    const gchar *value = luaL_checkstring(L, 3);
    JSCValue *res = jsc_value_object_invoke_method(element->element, "setAttribute", G_TYPE_STRING, attr, G_TYPE_STRING, value, G_TYPE_NONE);
    if (res) g_object_unref(res);
    return 0;
}

static gint
luaH_dom_element_push_attribute_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_attribute_index, 1);
    lua_rawset(L, -3);
    /* push __newindex metafunction */
    lua_pushliteral(L, "__newindex");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_attribute_newindex, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_style_index(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *name = luaL_checkstring(L, 2);
    JSCContext *ctx = jsc_value_get_context(element->element);
    JSCValue *window = jsc_context_get_value(ctx, "window");
    JSCValue *style = jsc_value_object_invoke_method(window, "getComputedStyle", JSC_TYPE_VALUE, element->element, G_TYPE_NONE);
    JSCValue *val_obj = jsc_value_object_invoke_method(style, "getPropertyValue", G_TYPE_STRING, name, G_TYPE_NONE);
    gchar *value = jsc_value_to_string(val_obj);
    lua_pushstring(L, value);
    g_free(value);
    g_object_unref(val_obj);
    g_object_unref(style);
    g_object_unref(window);
    return 1;
}

static gint
luaH_dom_element_push_style_table(lua_State *L)
{
    /* create style table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_element_style_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_element_click(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *ret = jsc_value_object_invoke_method(element->element, "click", G_TYPE_NONE);
    if (ret) g_object_unref(ret);
    return 0;
}

static gint
luaH_dom_element_focus(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *ret = jsc_value_object_invoke_method(element->element, "focus", G_TYPE_NONE);
    if (ret) g_object_unref(ret);
    return 0;
}

static gint
luaH_dom_element_submit(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *ret = jsc_value_object_invoke_method(element->element, "submit", G_TYPE_NONE);
    if (ret) g_object_unref(ret);
    return 0;
}

static gint
luaH_dom_element_emit_dom_event(lua_State *L, JSCValue *event, gint oud, const gchar *name) {
    gint nargs = 1;
    gint nret = 0;
    gint ret, top, bot = lua_gettop(L) - nargs + 1;
    gint oud_abs = luaH_absindex(L, oud);
    dom_element_t *obj = luaH_check_dom_element(L, oud);

    gchar *origin = luaH_callerinfo(L);
    debug("emit dom event " ANSI_COLOR_BLUE "\"%s\"" ANSI_COLOR_RESET
            " on %p from "
            ANSI_COLOR_GREEN "%s" ANSI_COLOR_RESET " (%d args, %d nret)",
            name, obj, origin ? origin : "<GTK>", nargs, nret);
    g_free(origin);

    if(!obj)
        return luaL_error(L, "trying to emit dom event " ANSI_COLOR_BLUE "\"%s\"" ANSI_COLOR_RESET " on non-object", name);

    signal_array_t *sigfuncs = signal_lookup(obj->dom_events, name);
    if (sigfuncs) {
        guint nbfunc = sigfuncs->len;
        luaL_checkstack(L, lua_gettop(L) + nbfunc + nargs + 2,
                "too many signal handlers; need a new implementation!");
        for (guint i = 0; i < nbfunc; i++)
            luaH_object_push_item(L, oud_abs, sigfuncs->pdata[i]);

        gboolean cancel = false;
        for (guint i = 0; i < nbfunc; i++) {
            lua_pushvalue(L, oud_abs);
            lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            lua_remove(L, - nargs - nbfunc - 2 + i);
            top = lua_gettop(L) - 2 - nargs;

            luaH_dofunction(L, nargs + 1, LUA_MULTRET);
            ret = lua_gettop(L) - top;

            lua_pop(L, ret);

            lua_pushvalue(L, - nargs - nbfunc + 1 + i);

            lua_pushliteral(L, "prevent_default");
            lua_rawget(L, -2);

            if (lua_toboolean(L, -1)) {
                JSCValue *prv = jsc_value_object_invoke_method(event, "preventDefault", G_TYPE_NONE);
                if (prv) g_object_unref(prv);
            }
            lua_pop(L, 1);

            lua_pushliteral(L, "cancel");
            lua_rawget(L, -2);

            if (lua_toboolean(L, -1)) {
                JSCValue *stp = jsc_value_object_invoke_method(event, "stopPropagation", G_TYPE_NONE);
                if (stp) g_object_unref(stp);
                cancel = true;
            }

            lua_pop(L, 2);

            if (cancel) {
                for (gint i = bot; i < top; i++)
                    lua_remove(L, bot);
                break;
            }
        }
    }
    lua_pop(L, nargs);
    return 0;
}

static void
js_dom_event_callback(JSCValue *element_val, JSCValue *event_val, const gchar *type, gboolean capture, gpointer UNUSED(user_data))
{
    lua_State *L = common.L;

    luaH_dom_element_from_node(L, element_val);

    lua_createtable(L, 0, 8);

    lua_pushliteral(L, "target");
    JSCValue *target = jsc_value_object_get_property(event_val, "target");
    luaH_dom_element_from_node(L, target);
    g_object_unref(target);
    lua_rawset(L, -3);

    lua_pushliteral(L, "type");
    lua_pushstring(L, type);
    lua_rawset(L, -3);

    gchar *staged_type = g_strjoin("::", type, (capture ? "capture" : "bubble"), NULL);

    lua_pushliteral(L, "phase");
    JSCValue *phase = jsc_value_object_get_property(event_val, "eventPhase");
    lua_pushinteger(L, jsc_value_to_int32(phase));
    g_object_unref(phase);
    lua_rawset(L, -3);

    JSCValue *has_button = jsc_value_object_get_property(event_val, "button");
    if (!jsc_value_is_undefined(has_button)) {
        lua_pushliteral(L, "button");
        lua_pushinteger(L, jsc_value_to_int32(has_button));
        lua_rawset(L, -3);
    }
    g_object_unref(has_button);

    JSCValue *has_key = jsc_value_object_get_property(event_val, "key");
    if (!jsc_value_is_undefined(has_key) && !jsc_value_is_null(has_key)) {
        lua_pushliteral(L, "key");
        gchar *key_str = jsc_value_to_string(has_key);
        lua_pushstring(L, key_str);
        g_free(key_str);
        lua_rawset(L, -3);

#define SET_MOD(name, js_name) \
        JSCValue *js_##name = jsc_value_object_get_property(event_val, js_name); \
        lua_pushliteral(L, #name); \
        lua_pushboolean(L, jsc_value_to_boolean(js_##name)); \
        g_object_unref(js_##name); \
        lua_rawset(L, -3);

        SET_MOD(ctrl_key, "ctrlKey")
        SET_MOD(alt_key, "altKey")
        SET_MOD(shift_key, "shiftKey")
        SET_MOD(meta_key, "metaKey")
#undef SET_MOD
    }
    g_object_unref(has_key);

    luaH_dom_element_emit_dom_event(L, event_val, -2, staged_type);
    g_free(staged_type);

    lua_pop(L, 1);
}

void
luaH_dom_element_add_dom_event(lua_State *L, gint oud,
        const gchar *name, gint ud) {
    luaH_checkfunction(L, ud);
    dom_element_t *obj = luaH_check_dom_element(L, oud);

    gchar *origin = luaH_callerinfo(L);
    debug("add dom event " ANSI_COLOR_BLUE "\"%s\"" ANSI_COLOR_RESET
            " on %p from " ANSI_COLOR_GREEN "%s" ANSI_COLOR_RESET,
            name, obj, origin);
    g_free(origin);

    signal_add(obj->dom_events, name, luaH_object_ref_item(L, oud, ud));
}

void
luaH_dom_element_remove_dom_event(lua_State *L, gint oud,
        const gchar *name, gint ud) {
    luaH_checkfunction(L, ud);
    dom_element_t *obj = luaH_check_dom_element(L, oud);
    gpointer ref = (gpointer) lua_topointer(L, ud);

    gchar *origin = luaH_callerinfo(L);
    debug("remove dom event " ANSI_COLOR_BLUE "\"%s\"" ANSI_COLOR_RESET
            " on %p from " ANSI_COLOR_GREEN "%s" ANSI_COLOR_RESET,
            name, obj, origin);
    g_free(origin);

    signal_remove(obj->dom_events, name, ref);

    luaH_object_unref_item(L, oud, ref);
    lua_remove(L, ud);
}

static gint
luaH_dom_element_add_event_listener(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const gchar *type = luaL_checkstring(L, 2);
    gboolean capture = lua_toboolean(L, 3);
    luaH_checkfunction(L, 4);
    gboolean ret = true;

    gchar *staged_type = g_strjoin("::", type, (capture ? "capture" : "bubble" ), NULL);

    signal_array_t *signals = signal_lookup(element->dom_events, staged_type);

    if (!signals || (signals && signals->len == 0)) {
        JSCContext *ctx = jsc_value_get_context(element->element);
        JSCValue *cb_func = jsc_context_get_value(ctx, "_luakit_dom_event_callback");
        if (jsc_value_is_undefined(cb_func)) {
            cb_func = jsc_value_new_function(ctx, NULL, G_CALLBACK(js_dom_event_callback), NULL, NULL, G_TYPE_NONE, 4, JSC_TYPE_VALUE, JSC_TYPE_VALUE, G_TYPE_STRING, G_TYPE_BOOLEAN);
            jsc_context_set_value(ctx, "_luakit_dom_event_callback", cb_func);
        }
        g_object_unref(cb_func);

        JSCValue *add_listener_fn = jsc_context_evaluate_with_source_uri(ctx,
            "(function(elem, type, capture) {\n"
            "    elem.addEventListener(type, function(event) {\n"
            "        _luakit_dom_event_callback(elem, event, type, capture);\n"
            "    }, capture);\n"
            "})", -1, NULL, 1);

        JSCValue *res = jsc_value_function_call(add_listener_fn, G_TYPE_NONE, JSC_TYPE_VALUE, element->element, G_TYPE_STRING, type, G_TYPE_BOOLEAN, capture, G_TYPE_NONE);
        if (res) g_object_unref(res);
        g_object_unref(add_listener_fn);
    }

    luaH_dom_element_add_dom_event(L, 1, staged_type, 4);
    g_free(staged_type);

    lua_pop(L, 3);
    lua_pushboolean(L, ret);

    return 1;
}

static gint
luaH_dom_element_remove_event_listener(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const gchar *type = luaL_checkstring(L, 2);
    gboolean capture = lua_toboolean(L, 3);
    luaH_checkfunction(L, 4);

    gchar *staged_type = g_strjoin("::", type, (capture ? "capture" : "bubble" ), NULL);
    luaH_dom_element_remove_dom_event(L, 1, staged_type, 4);
    g_free(staged_type);

    lua_pushboolean(L, TRUE);
    return 1;
}

static gint
luaH_dom_element_push_src(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *src = jsc_value_object_get_property(element->element, "src");
    if (!jsc_value_is_undefined(src) && !jsc_value_is_null(src)) {
        gchar *str = jsc_value_to_string(src);
        lua_pushstring(L, str);
        g_free(str);
        g_object_unref(src);
        return 1;
    }
    g_object_unref(src);
    return 0;
}

static gint
luaH_dom_element_push_href(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *href = jsc_value_object_get_property(element->element, "href");
    if (!jsc_value_is_undefined(href) && !jsc_value_is_null(href)) {
        gchar *str = jsc_value_to_string(href);
        lua_pushstring(L, str);
        g_free(str);
        g_object_unref(href);
        return 1;
    }
    g_object_unref(href);
    return 0;
}

static gint
luaH_dom_element_push_value(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *val = jsc_value_object_get_property(element->element, "value");
    if (!jsc_value_is_undefined(val) && !jsc_value_is_null(val)) {
        gchar *str = jsc_value_to_string(val);
        lua_pushstring(L, str);
        g_free(str);
        g_object_unref(val);
        return 1;
    }
    g_object_unref(val);
    return 0;
}

static gint
dom_html_element_set_value(lua_State *L, dom_element_t *element)
{
    const gchar *value = luaL_checkstring(L, 3);
    JSCContext *ctx = jsc_value_get_context(element->element);
    JSCValue *val_obj = jsc_value_new_string(ctx, value);
    jsc_value_object_set_property(element->element, "value", val_obj);
    g_object_unref(val_obj);
    return 1;
}

static gint
luaH_dom_element_client_rects(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *rects = jsc_value_object_invoke_method(element->element, "getClientRects", G_TYPE_NONE);
    JSCValue *len_val = jsc_value_object_get_property(rects, "length");
    gint num_rects = jsc_value_to_int32(len_val);
    g_object_unref(len_val);

    lua_createtable(L, num_rects, 0);
    for (gint i = 0; i < num_rects; ++i) {
        JSCValue *rect = jsc_value_object_get_property_at_index(rects, i);
        lua_newtable(L);

#define PROP(prop) \
        JSCValue *p_##prop = jsc_value_object_get_property(rect, #prop); \
        lua_pushnumber(L, jsc_value_to_double(p_##prop)); \
        g_object_unref(p_##prop); \
        lua_setfield(L, -2, #prop);

        PROP(top)
        PROP(right)
        PROP(bottom)
        PROP(left)
        PROP(width)
        PROP(height)
#undef PROP

        g_object_unref(rect);
        lua_rawseti(L, -2, i+1);
    }
    g_object_unref(rects);
    return 1;
}

static gint
luaH_dom_element_index(lua_State *L)
{
    if (luaH_usemetatable(L, 1, 2))
        return 1;

    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {
        PF_CASE(CLICK, luaH_dom_element_click);
        PF_CASE(FOCUS, luaH_dom_element_focus);
        PF_CASE(SUBMIT, luaH_dom_element_submit);
        PF_CASE(QUERY, luaH_dom_element_query);
        PF_CASE(APPEND, luaH_dom_element_append);
        PF_CASE(REMOVE, luaH_dom_element_remove);
        PF_CASE(ADD_EVENT_LISTENER, luaH_dom_element_add_event_listener);
        PF_CASE(REMOVE_EVENT_LISTENER, luaH_dom_element_remove_event_listener);
#if WEBKIT_CHECK_VERSION(2,18,0)
        PF_CASE(CLIENT_RECTS, luaH_dom_element_client_rects);
#endif
        case L_TK_RECT: return luaH_dom_element_push_rect_table(L);
        case L_TK_ATTR: return luaH_dom_element_push_attribute_table(L);
        case L_TK_STYLE: return luaH_dom_element_push_style_table(L);
        case L_TK_PARENT: {
            JSCValue *parent = jsc_value_object_get_property(element->element, "parentNode");
            gint ret = luaH_dom_element_from_node(L, parent);
            g_object_unref(parent);
            return ret;
        }
        case L_TK_TAG_NAME: {
            JSCValue *tag = jsc_value_object_get_property(element->element, "tagName");
            gchar *str = jsc_value_to_string(tag);
            lua_pushstring(L, str);
            g_free(str);
            g_object_unref(tag);
            return 1;
        }
        case L_TK_TEXT_CONTENT: {
            JSCValue *text = jsc_value_object_get_property(element->element, "textContent");
            gchar *str = jsc_value_to_string(text);
            lua_pushstring(L, str);
            g_free(str);
            g_object_unref(text);
            return 1;
        }
        case L_TK_FIRST_CHILD: {
            JSCValue *first = jsc_value_object_get_property(element->element, "firstChild");
            gint ret = luaH_dom_element_from_node(L, first);
            g_object_unref(first);
            return ret;
        }
        case L_TK_NEXT_SIBLING: {
            JSCValue *next = jsc_value_object_get_property(element->element, "nextSibling");
            gint ret = luaH_dom_element_from_node(L, next);
            g_object_unref(next);
            return ret;
        }
        case L_TK_OWNER_DOCUMENT: {
            JSCValue *doc = jsc_value_object_get_property(element->element, "ownerDocument");
            gint ret = luaH_dom_document_from_webkit_dom_document(L, doc);
            g_object_unref(doc);
            return ret;
        }
        case L_TK_VALUE: return luaH_dom_element_push_value(L);
        case L_TK_SRC: return luaH_dom_element_push_src(L);
        case L_TK_HREF: return luaH_dom_element_push_href(L);
        default: return 0;
    }
}

static gint
luaH_dom_element_newindex(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {
        case L_TK_VALUE:
            return dom_html_element_set_value(L, element);
        default:
            return 0;
    }
}

void
dom_element_class_setup(lua_State *L)
{
    static const struct luaL_Reg dom_element_methods[] =
    {
        LUA_CLASS_METHODS(dom_element)
        { NULL, NULL }
    };

    static const struct luaL_Reg dom_element_meta[] =
    {
        LUA_OBJECT_META(dom_element)
        { "__index", luaH_dom_element_index },
        { "__newindex", luaH_dom_element_newindex },
        { "__gc", luaH_dom_element_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &dom_element_class, "dom_element",
            (lua_class_allocator_t) dom_element_new,
            NULL, NULL,
            dom_element_methods, dom_element_meta);

    luaH_uniq_setup(L, REG_KEY, "");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
