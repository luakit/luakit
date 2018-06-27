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
#include <JavaScriptCore/JavaScript.h>

#include "extension/clib/dom_element.h"
#include "extension/clib/dom_document.h"
#include "common/luauniq.h"
#include "extension/extension.h"

#define REG_KEY "luakit.uniq.registry.dom_element"

static lua_class_t dom_element_class;

LUA_OBJECT_FUNCS(dom_element_class, dom_element_t, dom_element);

static dom_element_t*
luaH_check_dom_element(lua_State *L, gint udx)
{
    dom_element_t *element = luaH_checkudata(L, udx, &dom_element_class);
    if (!element->element || !WEBKIT_DOM_IS_ELEMENT(element->element))
        luaL_argerror(L, udx, "DOM element no longer valid");
    return element;
}

static void
webkit_web_page_destroy_cb(dom_element_t *element, GObject *node)
{
    lua_State *L = common.L;
    luaH_uniq_get_ptr(L, REG_KEY, node);
    luaH_object_emit_signal(L, -1, "destroy", 0, 0);
    lua_pop(L, 1);

    element->element = NULL;
    luaH_uniq_del_ptr(common.L, REG_KEY, node);
}

gint
luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node)
{
    if (!node) {
        lua_pushnil(L);
        return 1;
    }

    if (luaH_uniq_get_ptr(L, REG_KEY, node))
        return 1;

    dom_element_t *element = dom_element_new(L);
    element->element = node;

    luaH_uniq_add_ptr(L, REG_KEY, node, -1);
    g_object_weak_ref(G_OBJECT(node), (GWeakNotify)webkit_web_page_destroy_cb, element);

    return 1;
}

dom_element_t *
luaH_to_dom_element(lua_State *L, gint idx)
{
    return luaH_toudata(L, idx, &dom_element_class);
}

static char *
dom_element_selector(dom_element_t *element)
{
    WebKitDOMNode *elem = WEBKIT_DOM_NODE(element->element), *parent;
    GPtrArray *parts = g_ptr_array_new_full(10, g_free);

    while ((parent = webkit_dom_node_get_parent_node(elem))) {
        char *tag = webkit_dom_element_get_tag_name(WEBKIT_DOM_ELEMENT(elem));
        if (!strcmp(tag, "BODY") || !strcmp(tag, "HEAD")) {
            g_ptr_array_add(parts, g_strdup(tag));
            break;
        } else {
            int c = 1;
            WebKitDOMElement *e = WEBKIT_DOM_ELEMENT(elem), *ps;
            while ((ps = webkit_dom_element_get_previous_element_sibling(e))) {
                e = ps;
                c++;
            }
            g_ptr_array_add(parts, g_strdup_printf("%s:nth-child(%d)", tag, c));
        }
        elem = parent;
    }

    /* Reverse array and add null terminator for g_strjoinv() */
    for (guint i = 0, j = parts->len-1; i < j; i++, j--) {
        char *tmp = parts->pdata[i];
        parts->pdata[i] = parts->pdata[j];
        parts->pdata[j] = tmp;
    }
    g_ptr_array_add(parts, NULL);

    char *sel = g_strjoinv(" > ", (char **)parts->pdata);
    g_ptr_array_free(parts, TRUE);
    return sel;
}

JSValueRef
dom_element_js_ref(page_t *page, dom_element_t *element)
{
    gchar *sel = dom_element_selector(element);

    /* Get JSValueRef to document.getElementById() */
    WebKitFrame *frame = webkit_web_page_get_main_frame(page->page);
    WebKitScriptWorld *world = extension.script_world;
    JSGlobalContextRef ctx = webkit_frame_get_javascript_context_for_script_world(frame, world);

    JSObjectRef js_global = JSContextGetGlobalObject(ctx);
    JSStringRef doc_key = JSStringCreateWithUTF8CString("document");
    JSStringRef query_key = JSStringCreateWithUTF8CString("querySelector");
    JSStringRef sel_key = JSStringCreateWithUTF8CString(sel);
    JSValueRef sel_val = JSValueMakeString(ctx, sel_key);

    JSValueRef js_doc = JSObjectGetProperty(ctx, js_global, doc_key, NULL);
    JSValueRef js_get_elem = JSObjectGetProperty(ctx, (JSObjectRef)js_doc, query_key, NULL);
    JSValueRef ret = JSObjectCallAsFunction(ctx, (JSObjectRef)js_get_elem, (JSObjectRef)js_doc, 1, &sel_val, NULL);

    JSStringRelease(doc_key);
    JSStringRelease(query_key);
    JSStringRelease(sel_key);
    g_free(sel);

    return ret;
}

static gint
luaH_dom_element_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_element_query(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMElement *elem = element->element;
    const char *query = luaL_checkstring(L, 2);
    GError *error = NULL;

    WebKitDOMNodeList *nodes = webkit_dom_element_query_selector_all(elem, query, &error);

    if (error)
        return luaL_error(L, "query error: %s", error->message);

    gulong n = webkit_dom_node_list_get_length(nodes);

    lua_createtable(L, n, 0);
    for (gulong i=0; i<n; i++) {
        WebKitDOMNode *node = webkit_dom_node_list_item(nodes, i);
        luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(node));
        lua_rawseti(L, 3, i+1);
    }

    return 1;
}

static gint
luaH_dom_element_append(lua_State *L)
{
    dom_element_t *parent = luaH_check_dom_element(L, 1),
                  *child = luaH_check_dom_element(L, 2);
    WebKitDOMNode *p = WEBKIT_DOM_NODE(parent->element),
                  *c = WEBKIT_DOM_NODE(child->element);
    GError *error = NULL;
    webkit_dom_node_append_child(p, c, &error);
    return error ? luaL_error(L, "append element error: %s", error->message) : 0;
}

static gint
luaH_dom_element_remove(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    if (!WEBKIT_DOM_IS_ELEMENT(element->element))
        return 0;
    GError *error = NULL;
    webkit_dom_element_remove(element->element, &error);
    return error ? luaL_error(L, "remove element error: %s", error->message) : 0;
}

static void
dom_element_get_left_and_top(WebKitDOMElement *elem, glong *l, glong *t)
{
    if (!elem) {
        *l = 0;
        *t = 0;
    } else {
        dom_element_get_left_and_top(webkit_dom_element_get_offset_parent(elem), l, t);
        *l += webkit_dom_element_get_offset_left(elem);
        *l -= webkit_dom_element_get_scroll_left(elem);
        *t += webkit_dom_element_get_offset_top(elem);
        *t -= webkit_dom_element_get_scroll_top(elem);
    }
}

static gint
luaH_dom_element_rect_index(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = element->element;

    glong left, top;

    switch (token) {
        PI_CASE(WIDTH, webkit_dom_element_get_offset_width(elem));
        PI_CASE(HEIGHT, webkit_dom_element_get_offset_height(elem));
        case L_TK_LEFT:
        case L_TK_TOP:
            dom_element_get_left_and_top(elem, &left, &top);
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
    const gchar *attr = webkit_dom_element_get_attribute(element->element, name);
    lua_pushstring(L, attr);
    return 1;
}

static gint
luaH_dom_element_attribute_newindex(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, lua_upvalueindex(1));
    const gchar *attr = luaL_checkstring(L, 2);
    const gchar *value = luaL_checkstring(L, 3);
    GError *error = NULL;
    webkit_dom_element_set_attribute(element->element, attr, value, &error);
    return error ? luaL_error(L, "attribute error: %s", error->message) : 0;
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
    WebKitDOMDocument *document = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(element->element));
    WebKitDOMDOMWindow *window = webkit_dom_document_get_default_view(document);
    WebKitDOMCSSStyleDeclaration *style = webkit_dom_dom_window_get_computed_style(window, element->element, "");

    const gchar *name = luaL_checkstring(L, 2);
    const gchar *value = webkit_dom_css_style_declaration_get_property_value(style, name);
    lua_pushstring(L, value);
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
    WebKitDOMElement *elem = element->element;
    WebKitDOMDocument *doc = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(elem));
    WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);
    GError *error = NULL;
    WebKitDOMEvent *event = webkit_dom_document_create_event(doc, "MouseEvent", &error);
    if (error)
        return luaL_error(L, "create event error: %s", error->message);
    webkit_dom_event_init_event(event, "click", TRUE, TRUE);
    webkit_dom_event_target_dispatch_event(target, event, &error);
    if (error)
        return luaL_error(L, "dispatch event error: %s", error->message);
    return 0;
}

static gint
luaH_dom_element_focus(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    webkit_dom_element_focus(element->element);
    return 0;
}

static gint
luaH_dom_element_submit(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    webkit_dom_html_form_element_submit(WEBKIT_DOM_HTML_FORM_ELEMENT(element->element));
    return 0;
}

static void
event_listener_cb(WebKitDOMElement *UNUSED(elem), WebKitDOMEvent *event, gpointer func)
{
    lua_State *L = common.L;

    lua_createtable(L, 0, 1);
    lua_pushvalue(L, -1); /* pushing copy of cb argument */
    lua_pushliteral(L, "target");
    WebKitDOMEventTarget *target = webkit_dom_event_get_src_element(event);
    luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(target));
    lua_rawset(L, -3);

    lua_pushliteral(L, "type");
    gchar *type = webkit_dom_event_get_event_type(event);
    lua_pushstring(L, type);
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

    luaH_object_push(L, func);
    luaH_dofunction(L, 1, 0);

    /* after calling callback examine field 'cancel' in argument
       passed to callback and if it set to true then call
       stopPropagation */
    lua_pushliteral(L, "cancel");
    lua_rawget(L, -2);
    if (lua_toboolean(L, -1)) webkit_dom_event_stop_propagation(event);
    lua_pop(L, 1);
    /* also check if prevent_default set to true and if it's set then
       call webkit_dom_event_prevent_default for event */
    lua_pushliteral(L, "prevent_default");
    lua_rawget(L, -2);
    if (lua_toboolean(L, -1)) webkit_dom_event_prevent_default(event);
    lua_pop(L, 2);
}

static gint
luaH_dom_element_add_event_listener(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const gchar *type = luaL_checkstring(L, 2);
    gboolean capture = lua_toboolean(L, 3);
    luaH_checkfunction(L, 4);
    gpointer func = luaH_object_ref(L, 4);

    WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);

    gboolean ret = webkit_dom_event_target_add_event_listener(target, type,
            G_CALLBACK(event_listener_cb), capture, func);

    lua_pushboolean(L, ret);
    return 1;
}

/* because we processing all events in one signle event_listener_cb
   removing even listener will removes all listeners of this type on
   element, probably we can somehow scan registered listeners and
   remove only those one that have func as user data */
static gint
luaH_dom_element_remove_event_listener(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    const gchar *type = luaL_checkstring(L, 2);
    gboolean capture = lua_toboolean(L, 3);

    WebKitDOMEventTarget *target = WEBKIT_DOM_EVENT_TARGET(element->element);
    gboolean ret = webkit_dom_event_target_remove_event_listener(target, type,
            G_CALLBACK(event_listener_cb), capture);

    lua_pushboolean(L, ret);
    return 1;
}

#if WEBKIT_CHECK_VERSION(2,18,0)
static gint
luaH_dom_element_client_rects(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMClientRectList *rects = webkit_dom_element_get_client_rects(element->element);
    int num_rects = webkit_dom_client_rect_list_get_length(rects);

    lua_createtable(L, num_rects, 0);
    for (int i = 0; i < num_rects; ++i) {
        WebKitDOMClientRect* rect = webkit_dom_client_rect_list_item(rects, i);
        lua_newtable(L);
#define PROP(prop) \
            lua_pushnumber(L, webkit_dom_client_rect_get_##prop(rect)); \
            lua_setfield(L, -2, #prop);
        PROP(top)
        PROP(right)
        PROP(bottom)
        PROP(left)
        PROP(width)
        PROP(height)
#undef PROP
        lua_rawseti(L, -2, i+1);
    }

    return 1;
}
#endif

static gint
luaH_dom_element_push_src(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);

#define CHECK(lower, upper) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element->element)) { \
        lua_pushstring(L, webkit_dom_html_##lower##_element_get_src(WEBKIT_DOM_HTML_##upper##_ELEMENT(element->element))); \
        return 1; \
    }

    CHECK(input, INPUT);
    CHECK(frame, FRAME);
    CHECK(iframe, IFRAME);
    CHECK(embed, EMBED);
    CHECK(image, IMAGE);
    CHECK(script, SCRIPT);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_href(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);

#define CHECK(lower, upper) \
    if (WEBKIT_DOM_IS_##upper(element->element)) { \
        lua_pushstring(L, webkit_dom_##lower##_get_href(WEBKIT_DOM_##upper(element->element))); \
        return 1; \
    }

    CHECK(html_anchor_element, HTML_ANCHOR_ELEMENT);
    CHECK(html_area_element, HTML_AREA_ELEMENT);
    CHECK(html_link_element, HTML_LINK_ELEMENT);
    CHECK(style_sheet, STYLE_SHEET);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_value(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);

#define CHECK(lower, upper, type) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element->element)) { \
        lua_push##type(L, webkit_dom_html_##lower##_element_get_value( \
                    WEBKIT_DOM_HTML_##upper##_ELEMENT(element->element))); \
        return 1; \
    }

    CHECK(text_area, TEXT_AREA, string);
    CHECK(input, INPUT, string);
    CHECK(option, OPTION, string);
    CHECK(param, PARAM, string);
    CHECK(li, LI, integer);
    CHECK(button, BUTTON, string);
    CHECK(select, SELECT, string);

#undef CHECK

    return 0;
}

static gint
dom_html_element_set_value(lua_State *L, WebKitDOMHTMLElement *element)
{

#define CHECK(lower, upper, type) \
    if (WEBKIT_DOM_IS_HTML_##upper##_ELEMENT(element)) { \
        webkit_dom_html_##lower##_element_set_value( \
                WEBKIT_DOM_HTML_##upper##_ELEMENT(element), \
                luaL_check##type(L, 3)); \
        return 1; \
    }

    CHECK(text_area, TEXT_AREA, string);
    CHECK(input, INPUT, string);
    CHECK(option, OPTION, string);
    CHECK(param, PARAM, string);
    CHECK(li, LI, integer);
    CHECK(button, BUTTON, string);
    CHECK(select, SELECT, string);

#undef CHECK

    return 0;
}

static gint
luaH_dom_element_push_parent(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMNode *parent = webkit_dom_node_get_parent_node(WEBKIT_DOM_NODE(element->element));
    return luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(parent));
}

static gint
luaH_dom_element_push_first_child(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMElement *elem = element->element;
    WebKitDOMElement *child = webkit_dom_element_get_first_element_child(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_last_child(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMElement *elem = element->element;
    WebKitDOMElement *child = webkit_dom_element_get_last_element_child(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_prev_sibling(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMElement *elem = element->element;
    WebKitDOMElement *child = webkit_dom_element_get_previous_element_sibling(elem);
    return luaH_dom_element_from_node(L, child);
}

static gint
luaH_dom_element_push_next_sibling(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMElement *elem = element->element;
    WebKitDOMElement *child = webkit_dom_element_get_next_element_sibling(elem);
    return luaH_dom_element_from_node(L, child);
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
        return 0;

    return luaH_dom_document_from_webkit_dom_document(L, doc);
}

static gint
luaH_dom_element_push_owner_document(lua_State *L)
{
    dom_element_t *element = luaH_check_dom_element(L, 1);
    WebKitDOMDocument *doc = webkit_dom_node_get_owner_document(WEBKIT_DOM_NODE(element->element));
    return luaH_dom_document_from_webkit_dom_document(L, doc);
}

static gint
luaH_dom_element_index(lua_State *L)
{
    if (luaH_usemetatable(L, 1, 2))
        return 1;

    dom_element_t *element = luaH_check_dom_element(L, 1);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = element->element;

    switch(token) {
        PS_CASE(TAG_NAME, webkit_dom_element_get_tag_name(elem))
        PS_CASE(TEXT_CONTENT, webkit_dom_node_get_text_content(WEBKIT_DOM_NODE(elem)))
        PS_CASE(INNER_HTML, webkit_dom_element_get_inner_html(elem))

        PF_CASE(QUERY, luaH_dom_element_query)
        PF_CASE(APPEND, luaH_dom_element_append)
        PF_CASE(REMOVE, luaH_dom_element_remove)
        PF_CASE(CLICK, luaH_dom_element_click)
        PF_CASE(FOCUS, luaH_dom_element_focus)
        PF_CASE(SUBMIT, luaH_dom_element_submit)
        PF_CASE(ADD_EVENT_LISTENER, luaH_dom_element_add_event_listener)
        PF_CASE(REMOVE_EVENT_LISTENER, luaH_dom_element_remove_event_listener)
#if WEBKIT_CHECK_VERSION(2,18,0)
        PF_CASE(CLIENT_RECTS, luaH_dom_element_client_rects)
#endif

        PI_CASE(CHILD_COUNT, webkit_dom_element_get_child_element_count(elem))

        case L_TK_SRC: return luaH_dom_element_push_src(L);
        case L_TK_HREF: return luaH_dom_element_push_href(L);
        case L_TK_VALUE: return luaH_dom_element_push_value(L);
        case L_TK_CHECKED: return webkit_dom_html_input_element_get_checked(
                                   WEBKIT_DOM_HTML_INPUT_ELEMENT(elem));
        case L_TK_TYPE: {
            gchar *type;
            g_object_get(element->element, "type", &type, NULL);
            lua_pushstring(L, type);
            return 1;
        }
        case L_TK_PARENT: return luaH_dom_element_push_parent(L);
        case L_TK_FIRST_CHILD: return luaH_dom_element_push_first_child(L);
        case L_TK_LAST_CHILD: return luaH_dom_element_push_last_child(L);
        case L_TK_PREV_SIBLING: return luaH_dom_element_push_prev_sibling(L);
        case L_TK_NEXT_SIBLING: return luaH_dom_element_push_next_sibling(L);
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

    GError *error = NULL;

    switch (token) {
        case L_TK_INNER_HTML:
            webkit_dom_element_set_inner_html(element->element,
                    luaL_checkstring(L, 3), &error);
            if (error)
                return luaL_error(L, "set inner html error: %s", error->message);
            break;
        case L_TK_VALUE:
            if (!dom_html_element_set_value(L, WEBKIT_DOM_HTML_ELEMENT(element->element)))
                return luaL_error(L, "set value error: wrong element type");
            break;
        case L_TK_CHECKED:
            webkit_dom_html_input_element_set_checked(
                    WEBKIT_DOM_HTML_INPUT_ELEMENT(element->element),
                    lua_toboolean(L, 3));
            return 0;
        default:
            break;
    }

    return 0;
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
