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

#include <webkitdom/webkitdom.h>
#define WEBKIT_DOM_USE_UNSTABLE_API
#include <webkitdom/WebKitDOMElementUnstable.h>
#include <webkitdom/WebKitDOMDOMWindowUnstable.h>
#include <jsc/jsc.h>

#include "extension/clib/dom_element.h"
#include "extension/clib/dom_document.h"
#include "common/luajs.h"
#include "common/luauniq.h"
#include "common/util.h"
#include "extension/extension.h"

#define REG_KEY "luakit.uniq.registry.dom_element"

static lua_class_t dom_element_class;

LUA_DOM_ELEMENT_FUNCS(dom_element_class, dom_element_t, dom_element);

#define L_DOM_ELEMENT_TO_JSC_VALUE(e) webkit_frame_get_js_value_for_dom_object(webkit_web_page_get_main_frame(e->page), WEBKIT_DOM_OBJECT(e->element))

static dom_element_t*
luaH_check_dom_element(lua_State *L, gint udx)
{
    dom_element_t *element = luaH_checkudata(L, udx, &dom_element_class);
    if (!element->element || !WEBKIT_DOM_IS_ELEMENT(element->element))
        luaL_argerror(L, udx, "DOM element no longer valid");
    return element;
}

static gboolean
dom_element_collect_event_keys(gpointer key, gpointer UNUSED(value), GPtrArray *keys)
{
    g_ptr_array_add(keys, key);
    return FALSE;
}

/* forward declarations of callbacks */
static void event_listener_capture_cb(WebKitDOMElement *elem, WebKitDOMEvent *event, dom_element_t *element);
static void event_listener_bubble_cb(WebKitDOMElement *elem, WebKitDOMEvent *event, dom_element_t *element);

static void
dom_element_unregister_webkit_event_listeners(dom_element_t *element)
{
    if (element && element->element && element->dom_events) {
        WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);
        if (target) {
            guint i;
            GPtrArray *keys = g_ptr_array_new();
            /* collect all existing webkit listener's types registerd for this element */
            g_tree_foreach(element->dom_events, (GTraverseFunc)dom_element_collect_event_keys, keys);
            /* remove all registered webkit listeners for both capture and bubble phases */
            for (i = 0; i < keys->len; i++) {
                char *type = g_ptr_array_index(keys, i);
                if ( g_str_has_suffix(type, "::capture" ) )
                    webkit_dom_event_target_remove_event_listener(target, type,
                                                                  G_CALLBACK(event_listener_capture_cb), TRUE);
                else
                    webkit_dom_event_target_remove_event_listener(target, type,
                                                                  G_CALLBACK(event_listener_bubble_cb), FALSE);
            }
            g_ptr_array_free(keys, FALSE);
        }
    }
}

static void
webkit_web_page_destroy_cb(dom_element_t *element, GObject *node)
{
    lua_State *L = common.L;
    luaH_uniq_get_ptr(L, REG_KEY, node);
    luaH_object_emit_signal(L, -1, "destroy", 0, 0);
    lua_pop(L, 1);

    dom_element_unregister_webkit_event_listeners(element);

    element->element = NULL;
    luaH_uniq_del_ptr(common.L, REG_KEY, node);
}

static gint
luaH_dom_element_gc(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    if (element) {
        dom_element_unregister_webkit_event_listeners(element);

        if (element->dom_events)
            signal_destroy(element->dom_events);
    }
    return luaH_object_gc(L);
}

gint
luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node, WebKitWebPage *page)
{
    if (!node) {
        lua_pushnil(L);
        return 1;
    }

    if (luaH_uniq_get_ptr(L, REG_KEY, node))
        return 1;

    dom_element_t *element = dom_element_new(L);
    element->element = node;
    element->page = page;

    luaH_uniq_add_ptr(L, REG_KEY, node, -1);
    g_object_weak_ref(G_OBJECT(node), (GWeakNotify)webkit_web_page_destroy_cb, element);

    return 1;
}

dom_element_t *
luaH_to_dom_element(lua_State *L, gint idx)
{
    return luaH_toudata(L, idx, &dom_element_class);
}

static gint
luaH_dom_element_query(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *query = luaL_checkstring(L, 2);

    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);

    JSCValue *node_list = jsc_value_object_invoke_method(ref, "querySelectorAll", G_TYPE_STRING, query, G_TYPE_NONE);
    JSCException *e = jsc_context_get_exception(jsc_value_get_context(ref));
    if (e) {
        g_object_unref(node_list);
        return luaL_error(L, "query error: %s", jsc_exception_to_string(e));
    }

    JSCValue *length = jsc_value_object_get_property(node_list, "length");
    int n = jsc_value_to_int32(length);
    g_object_unref(length);

    lua_createtable(L, n, 0);
    for (gulong i=0; i<n; i++) {
        JSCValue *node = jsc_value_object_get_property_at_index(node_list, i);
        luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(webkit_dom_node_for_js_value(node)), element->page);
        g_object_unref(node);
        lua_rawseti(L, 3, i+1);
    }

    g_object_unref(node_list);

    return 1;
}

static gint
luaH_dom_element_append(lua_State *L)
{
    dom_element_t *parent = luaH_check_dom_element(L, 1),
                  *child = luaH_check_dom_element(L, 2);
    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(parent);

    g_object_unref(jsc_value_object_invoke_method(ref, "appendChild", JSC_TYPE_VALUE, L_DOM_ELEMENT_TO_JSC_VALUE(child), G_TYPE_NONE));

    JSCException *e = jsc_context_get_exception(jsc_value_get_context(ref));
    return e ? luaL_error(L, "append element error: %s", jsc_exception_to_string(e)) : 0;
}

static gint
luaH_dom_element_remove(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);
    if (!jsc_value_object_is_instance_of(ref, "Element"))
        return 0;
    g_object_unref(jsc_value_object_invoke_method(ref, "remove", G_TYPE_NONE));
    JSCException *e = jsc_context_get_exception(jsc_value_get_context(ref));
    return e ? luaL_error(L, "remove element error: %s", jsc_exception_to_string(e)) : 0;
}

static void
dom_element_get_left_and_top(JSCValue *elem, glong *l, glong *t)
{
    if (!elem || !jsc_value_object_is_instance_of(elem, "Element")) {
        *l = 0;
        *t = 0;
    } else {
        JSCValue *offset_parent = jsc_value_object_get_property(elem, "offsetParent");
        dom_element_get_left_and_top(offset_parent, l, t);
        g_object_unref(offset_parent);

        JSCValue *ret;
        ret = jsc_value_object_get_property(elem, "offsetLeft");
        *l += jsc_value_to_int32(ret);
        g_object_unref(ret);
        ret = jsc_value_object_get_property(elem, "scrollLeft");
        *l -= jsc_value_to_int32(ret);
        g_object_unref(ret);
        ret = jsc_value_object_get_property(elem, "offsetTop");
        *t += jsc_value_to_int32(ret);
        g_object_unref(ret);
        ret = jsc_value_object_get_property(elem, "scrollTop");
        *t -= jsc_value_to_int32(ret);
        g_object_unref(ret);
    }
}

static gint
luaH_dom_element_rect_index(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    glong left, top;

    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);

    switch (token) {
        case L_TK_WIDTH:
            JSCValue *offsetWidth = jsc_value_object_get_property(ref, "offsetWidth");
            int offset_width = jsc_value_to_int32(offsetWidth);
            g_object_unref(offsetWidth);
            lua_pushinteger(L, offset_width);
            return 1;
        case L_TK_HEIGHT:
            JSCValue *offsetHeight = jsc_value_object_get_property(ref, "offsetHeight");
            int offset_height = jsc_value_to_int32(offsetHeight);
            g_object_unref(offsetHeight);
            lua_pushinteger(L, offset_height);
            return 1;
        case L_TK_LEFT:
        case L_TK_TOP:
            dom_element_get_left_and_top(ref, &left, &top);
            lua_pushinteger(L, token == L_TK_LEFT ? left : top);
            return 1;
        default:
            return 0;
    }
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
    JSCValue *attribute = jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(element), "getAttribute", G_TYPE_STRING, name, G_TYPE_NONE);
    int ret = luajs_pushvalue(L, attribute);
    g_object_unref(attribute);
    return ret;
}

static gint
luaH_dom_element_attribute_newindex(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *attr = luaL_checkstring(L, 2);
    const gchar *value = luaL_checkstring(L, 3);
    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);
    g_object_unref(jsc_value_object_invoke_method(ref, "setAttribute", G_TYPE_STRING, attr, G_TYPE_STRING, value, G_TYPE_NONE));
    JSCException *e = jsc_context_get_exception(jsc_value_get_context(ref));
    return e ? luaL_error(L, "attribute error: %s", jsc_exception_to_string(e)) : 0;
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
    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);
    JSCValue *window = jsc_context_get_value(jsc_value_get_context(ref), "window");
    JSCValue *computed_style = jsc_value_object_invoke_method(window, "getComputedStyle", JSC_TYPE_VALUE, ref, G_TYPE_NONE);

    const gchar *name = luaL_checkstring(L, 2);
    JSCValue *value = jsc_value_object_invoke_method(computed_style, "getPropertyValue", G_TYPE_STRING, name, G_TYPE_NONE);
    char *s = jsc_value_to_string(value);
    lua_pushstring(L, s);
    free(s);
    g_object_unref(value);

    g_object_unref(computed_style);
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
    g_object_unref(jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(element), "click", G_TYPE_NONE));
    return 0;
}

static gint
luaH_dom_element_focus(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    g_object_unref(jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(element), "focus", G_TYPE_NONE));
    return 0;
}

static gint
luaH_dom_element_submit(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    g_object_unref(jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(element), "submit", G_TYPE_NONE));
    return 0;
}

/* Emit a dom event to an object.
 * `event` is the webkit dom event.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 */
static gint
luaH_dom_element_emit_dom_event(lua_State *L, WebKitDOMEvent *event, gint oud, const gchar *name) {
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
        /* Push all functions and then execute, because this list can change
         * while executing funcs. */
        for (guint i = 0; i < nbfunc; i++)
            luaH_object_push_item(L, oud_abs, sigfuncs->pdata[i]);

        gboolean cancel = false;
        for (guint i = 0; i < nbfunc; i++) {
            /* push object */
            lua_pushvalue(L, oud_abs);
            /* push event arg */
            lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            /* push first function */
            lua_pushvalue(L, - nargs - nbfunc - 1 + i);
            /* remove this first function */
            lua_remove(L, - nargs - nbfunc - 2 + i);
            top = lua_gettop(L) - 2 - nargs;

            luaH_dofunction(L, nargs + 1, LUA_MULTRET);
            ret = lua_gettop(L) - top;

            /* ignore all return values */
            lua_pop(L, ret);

            /* push event arg */
            lua_pushvalue(L, - nargs - nbfunc + 1 + i);

            /* check if field 'prevent_default' set to true and if it's set then
               call webkit_dom_event_prevent_default for event */
            lua_pushliteral(L, "prevent_default");
            lua_rawget(L, -2);

            if (lua_toboolean(L, -1)) webkit_dom_event_prevent_default(event);
            lua_pop(L, 1);

            /* check if field 'cancel' and if it set to true then call
               stopPropagation */
            lua_pushliteral(L, "cancel");
            lua_rawget(L, -2);

            if (lua_toboolean(L, -1)) {
                webkit_dom_event_stop_propagation(event);
                cancel = true;
            }

            /* clean stack from cancel and table*/
            lua_pop(L, 2);

            /* if even should be canceled then cleanup stack */
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
event_listener_cb(WebKitDOMElement *UNUSED(elem), WebKitDOMEvent *event, gboolean capture, dom_element_t *element)
{
    lua_State *L = common.L;

    /* pushing dom element object to lua stack */
    luaH_uniq_get_ptr(L, REG_KEY, element->element);

    lua_createtable(L, 0, 1);
    lua_pushliteral(L, "target");
    WebKitDOMEventTarget *target = webkit_dom_event_get_src_element(event);
    luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(target), element->page);
    lua_rawset(L, -3);

    lua_pushliteral(L, "type");
    gchar *type = webkit_dom_event_get_event_type(event);
    lua_pushstring(L, type);
    lua_rawset(L, -3);

    gchar *staged_type = g_strjoin( "::", type, ( capture ? "capture" : "bubble" ), NULL);

    lua_pushliteral(L, "phase");
    gushort phase = webkit_dom_event_get_event_phase(event);
    lua_pushinteger(L, phase);
    lua_rawset(L, -3);

    if (WEBKIT_DOM_IS_MOUSE_EVENT(event)) {
        lua_pushliteral(L, "button");
        gushort button = webkit_dom_mouse_event_get_button(WEBKIT_DOM_MOUSE_EVENT(event));
        lua_pushinteger(L, button);
        lua_rawset(L, -3);
    }

    if (WEBKIT_DOM_IS_KEYBOARD_EVENT(event)) {
        lua_pushliteral(L, "key");
        gchar *key = webkit_dom_keyboard_event_get_key_identifier(WEBKIT_DOM_KEYBOARD_EVENT(event));
        lua_pushstring(L, key);
        lua_rawset(L, -3);

        lua_pushliteral(L, "code");
        glong code = webkit_dom_ui_event_get_char_code(WEBKIT_DOM_UI_EVENT(event));
        lua_pushinteger(L, code);
        lua_rawset(L, -3);

        lua_pushliteral(L, "ctrl_key");
        gboolean ctrl = webkit_dom_keyboard_event_get_ctrl_key(WEBKIT_DOM_KEYBOARD_EVENT(event));
        lua_pushboolean(L, ctrl);
        lua_rawset(L, -3);

        lua_pushliteral(L, "alt_key");
        gboolean alt = webkit_dom_keyboard_event_get_alt_key(WEBKIT_DOM_KEYBOARD_EVENT(event));
        lua_pushboolean(L, alt);
        lua_rawset(L, -3);

        lua_pushliteral(L, "shift_key");
        gboolean shift = webkit_dom_keyboard_event_get_shift_key(WEBKIT_DOM_KEYBOARD_EVENT(event));
        lua_pushboolean(L, shift);
        lua_rawset(L, -3);

        lua_pushliteral(L, "meta_key");
        gboolean meta = webkit_dom_keyboard_event_get_meta_key(WEBKIT_DOM_KEYBOARD_EVENT(event));
        lua_pushboolean(L, meta);
        lua_rawset(L, -3);
    }

    luaH_dom_element_emit_dom_event(L, event, -2, staged_type);
    g_free(staged_type);

    /* pop dom element from stack */
    lua_pop(L, 1);

}

static void
event_listener_capture_cb(WebKitDOMElement *elem, WebKitDOMEvent *event, dom_element_t *element)
{
    return event_listener_cb(elem, event, TRUE, element);
}

static void
event_listener_bubble_cb(WebKitDOMElement *elem, WebKitDOMEvent *event, dom_element_t *element)
{
    return event_listener_cb(elem, event, FALSE, element);
}

/* Add a dom event to an object.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 * `ud` is the index of function to call when dom event triggered. */
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

/* Remove a dom event from an object.
 * `oud` is the object index on the stack.
 * `name` is the name of the signal.
 * `ud` is the index of function that should be removed.
 */
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

    WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);

    gchar *staged_type = g_strjoin("::", type, (capture ? "capture" : "bubble" ), NULL);

    /* check if we already have any signals of required type in this dom element */
    signal_array_t *signals = signal_lookup(element->dom_events, staged_type);

    if (!signals || (signals && signals->len == 0)) {
        if (capture)
            ret = webkit_dom_event_target_add_event_listener(target, type,
                                                             G_CALLBACK(event_listener_capture_cb), capture, element);
        else
            ret = webkit_dom_event_target_add_event_listener(target, type,
                                                             G_CALLBACK(event_listener_bubble_cb), capture, element);
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
    gboolean ret = true;

    gchar *staged_type = g_strjoin("::", type, (capture ? "capture" : "bubble" ), NULL);

    /* remove func from dom element`s signals */
    luaH_dom_element_remove_dom_event(L, 1, staged_type, 4);

    /* retrieve remaining signals for dom element */
    signal_array_t *signals = signal_lookup(element->dom_events, staged_type);

    g_free(staged_type);

    /* if no more lua signal handlers registered -- remove it in webkit as well */
    if (!signals || (signals && signals->len == 0)) {
        WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);
        if (capture)
            ret = webkit_dom_event_target_remove_event_listener(target, type,
                                                                G_CALLBACK(event_listener_capture_cb), capture);
        else
            ret = webkit_dom_event_target_remove_event_listener(target, type,
                                                                G_CALLBACK(event_listener_bubble_cb), capture);
    }

    lua_pushboolean(L, ret);
    return 1;
}

static gint
luaH_dom_element_client_rects(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *rects = jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(element), "getClientRects", G_TYPE_NONE);

    JSCValue *length = jsc_value_object_get_property(rects, "length");
    int num_rects = jsc_value_to_int32(length);
    g_object_unref(length);

    lua_createtable(L, num_rects, 0);
    for (int i = 0; i < num_rects; ++i) {
        JSCValue *rect = jsc_value_object_get_property_at_index(rects, i);
        lua_newtable(L);
        char *properties[] = {"top", "right", "bottom", "left", "width", "height"};
        for (int j = 0; j < LENGTH(properties); j++) {
            JSCValue *property = jsc_value_object_get_property(rect, properties[j]);
            lua_pushnumber(L, jsc_value_to_int32(property));
            lua_setfield(L, -2, properties[j]);
            g_object_unref(property);
        }
        lua_rawseti(L, -2, i+1);
        g_object_unref(rect);
    }

    g_object_unref(rects);

    return 1;
}

static int luaH_dom_element_push_attribute(lua_State *L, char *attribute)
{
    dom_element_t *elem = luaH_check_dom_element(L, 1);
    JSCValue *value = jsc_value_object_invoke_method(L_DOM_ELEMENT_TO_JSC_VALUE(elem), "getAttribute", G_TYPE_STRING, attribute, G_TYPE_NONE);
    int ret = luajs_pushvalue(L, value);
    g_object_unref(value);
    return ret;
}

/*
 * Pushes the element corresponding to the named property of the DOM element on
 * the stack onto the stack. If the original element has no such property, nil
 * is pushed instead.
 */
static int luaH_dom_element_push_element(lua_State *L, const char *property)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *e = jsc_value_object_get_property(L_DOM_ELEMENT_TO_JSC_VALUE(element), property);
    if (jsc_value_is_null(e)) {
        g_object_unref(e);
        lua_pushnil(L);
        return 1;
    }
    int ret = luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(webkit_dom_node_for_js_value(e)), element->page);
    g_object_unref(e);
    return ret;
}

static gint
luaH_dom_element_push_document(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMDocument *doc;

    if (WEBKIT_DOM_IS_HTML_FRAME_ELEMENT(element->element)) {
        doc = webkit_dom_html_frame_element_get_content_document(
                WEBKIT_DOM_HTML_FRAME_ELEMENT(element->element));
    } else if (WEBKIT_DOM_IS_HTML_IFRAME_ELEMENT(element->element)) {
        doc = webkit_dom_html_iframe_element_get_content_document(
                WEBKIT_DOM_HTML_IFRAME_ELEMENT(element->element));
    } else
        doc = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(element->element));

    return luaH_dom_document_from_webkit_dom_document(L, doc, element->page);
}

static gint
luaH_dom_element_push_owner_document(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *doc = jsc_value_object_get_property(L_DOM_ELEMENT_TO_JSC_VALUE(element), "ownerDocument");
    int ret = luaH_dom_document_from_webkit_dom_document(L, WEBKIT_DOM_DOCUMENT(webkit_dom_node_for_js_value(doc)), element->page);
    g_object_unref(doc);
    return ret;
}

static int luaH_dom_element_push_property(lua_State *L, const char *property)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    JSCValue *value = jsc_value_object_get_property(L_DOM_ELEMENT_TO_JSC_VALUE(element), property);
    int ret = luajs_pushvalue(L, value);
    g_object_unref(value);
    return ret;
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
        case L_TK_TAG_NAME:
            return luaH_dom_element_push_property(L, "tagName");
        case L_TK_TEXT_CONTENT:
            return luaH_dom_element_push_property(L, "textContent");
        case L_TK_INNER_HTML:
            return luaH_dom_element_push_property(L, "innerHTML");

        PF_CASE(QUERY, luaH_dom_element_query)
        PF_CASE(APPEND, luaH_dom_element_append)
        PF_CASE(REMOVE, luaH_dom_element_remove)
        PF_CASE(CLICK, luaH_dom_element_click)
        PF_CASE(FOCUS, luaH_dom_element_focus)
        PF_CASE(SUBMIT, luaH_dom_element_submit)
        PF_CASE(ADD_EVENT_LISTENER, luaH_dom_element_add_event_listener)
        PF_CASE(REMOVE_EVENT_LISTENER, luaH_dom_element_remove_event_listener)
        PF_CASE(CLIENT_RECTS, luaH_dom_element_client_rects)

        case L_TK_CHILD_COUNT:
            return luaH_dom_element_push_property(L, "childElementCount");

        case L_TK_SRC:
            /*
             * Returning src as a property rather than attribute for backwards
             * compatibility, despite it being documented as an attribute. The
             * difference is that as an attribute, relative URLs will remain
             * relative whereas like this the complete URI is obtained.
             */
            return luaH_dom_element_push_property(L, "src");
        case L_TK_HREF:
            /*
             * Returning href as a property rather than attribute for backwards
             * compatibility, despite it being documented as an attribute. The
             * difference is that as an attribute, relative URLs will remain
             * relative whereas like this the complete URI is obtained.
             */
            return luaH_dom_element_push_property(L, "href");
        case L_TK_VALUE:
            /*
             * Handle value as a property to automatically get integer
             * conversion for <li> elements which is necessary to maintain
             * backwards compatibility.
             */
            return luaH_dom_element_push_property(L, "value");
        case L_TK_CHECKED:
            return luaH_dom_element_push_property(L, "checked");
        case L_TK_TYPE:
            return luaH_dom_element_push_attribute(L, "type");
        case L_TK_PARENT:
            return luaH_dom_element_push_element(L, "parentElement");
        case L_TK_FIRST_CHILD:
            return luaH_dom_element_push_element(L, "firstElementChild");
        case L_TK_LAST_CHILD:
            return luaH_dom_element_push_element(L, "lastElementChild");
        case L_TK_PREV_SIBLING:
            return luaH_dom_element_push_element(L, "previousElementSibling");
        case L_TK_NEXT_SIBLING:
            return luaH_dom_element_push_element(L, "nextElementSibling");
        case L_TK_RECT: return luaH_dom_element_push_rect_table(L);
        case L_TK_ATTR: return luaH_dom_element_push_attribute_table(L);
        case L_TK_STYLE: return luaH_dom_element_push_style_table(L);
        case L_TK_DOCUMENT: return luaH_dom_element_push_document(L);
        case L_TK_OWNER_DOCUMENT: return luaH_dom_element_push_owner_document(L);
        default:
            return 0;
    }
}

static gint
luaH_dom_element_newindex(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    char *name;
    switch (token) {
        case L_TK_INNER_HTML:
            name = "innerHTML";
            break;
        case L_TK_VALUE:
            name = "value";
            break;
        case L_TK_CHECKED:
            name = "checked";
            break;
        default:
            return 0;
    }

    JSCValue *ref = L_DOM_ELEMENT_TO_JSC_VALUE(element);

    JSCValue *value = luajs_tovalue(L, 3, jsc_value_get_context(ref));
    if (!value)
        return luaL_error(L, "failed to convert the Lua value to JavaScript");

    jsc_value_object_set_property(ref, name, value);
    g_object_unref(value);

    return luaH_object_property_signal(L, 1, token);
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
