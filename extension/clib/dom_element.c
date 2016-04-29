#include <webkitdom/webkitdom.h>

#include "extension/clib/dom_element.h"

LUA_OBJECT_FUNCS(dom_element_class, dom_element_t, dom_element);

gint
luaH_dom_element_from_node(lua_State *L, WebKitDOMElement* node)
{
    lua_newtable(L);
    luaH_class_new(L, &dom_element_class);
    lua_remove(L, -2);

    dom_element_t *element = luaH_checkudata(L, -1, &dom_element_class);
    element->element = WEBKIT_DOM_HTML_ELEMENT(node);

    return 1;
}

static gint
luaH_dom_element_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_element_query(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);
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
    dom_element_t *parent = luaH_checkudata(L, 1, &dom_element_class),
                  *child = luaH_checkudata(L, 2, &dom_element_class);
    WebKitDOMNode *p = WEBKIT_DOM_NODE(parent->element),
                  *c = WEBKIT_DOM_NODE(child->element);
    GError *error = NULL;

    webkit_dom_node_append_child(p, c, &error);

    if (error)
        return luaL_error(L, "create element error: %s", error->message);

    return 0;
}

static gint
luaH_dom_element_remove(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    GError *error = NULL;

    webkit_dom_element_remove(element->element, &error);

    if (error)
        return luaL_error(L, "remove element error: %s", error->message);

    return 0;
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
        *t += webkit_dom_element_get_offset_top(elem);
    }
}

static gint
luaH_dom_element_push_rect_table(lua_State *L, dom_element_t *element)
{
    glong left, top, width, height;
    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);

    dom_element_get_left_and_top(elem, &left, &top);
    width = webkit_dom_element_get_offset_width(elem);
    height = webkit_dom_element_get_offset_height(elem);

    lua_createtable(L, 0, 4);

    lua_pushstring(L, "left");
    lua_pushinteger(L, left);
    lua_rawset(L, -3);

    lua_pushstring(L, "top");
    lua_pushinteger(L, top);
    lua_rawset(L, -3);

    lua_pushstring(L, "width");
    lua_pushinteger(L, width);
    lua_rawset(L, -3);

    lua_pushstring(L, "height");
    lua_pushinteger(L, height);
    lua_rawset(L, -3);

    return 1;
}

static gint
luaH_dom_element_attribute_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *attr = luaL_checkstring(L, 2);
    lua_pushstring(L, webkit_dom_element_get_attribute(element->element, attr));
    return 1;
}

static gint
luaH_dom_element_attribute_newindex(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, lua_upvalueindex(1), &dom_element_class);
    const gchar *attr = luaL_checkstring(L, 2);
    const gchar *value = luaL_checkstring(L, 3);
    GError *error = NULL;

    webkit_dom_element_set_attribute(element->element, attr, value, &error);

    if (error)
        return luaL_error(L, "attribute error: %s", error->message);

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
luaH_dom_element_click(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    webkit_dom_html_element_click(WEBKIT_DOM_HTML_ELEMENT(element->element));
    return 0;
}

static gint
luaH_dom_element_focus(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    webkit_dom_element_focus(element->element);
    return 0;
}

static gint
luaH_dom_element_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);

    switch(token) {
        PS_CASE(TAG_NAME, webkit_dom_element_get_tag_name(elem))
        PS_CASE(TEXT_CONTENT, webkit_dom_node_get_text_content(WEBKIT_DOM_NODE(elem)))
        PF_CASE(QUERY, luaH_dom_element_query)
        PF_CASE(APPEND, luaH_dom_element_append)
        PF_CASE(REMOVE, luaH_dom_element_remove)
        PF_CASE(CLICK, luaH_dom_element_click)
        PF_CASE(FOCUS, luaH_dom_element_focus)
        case L_TK_RECT: return luaH_dom_element_push_rect_table(L, element);
        case L_TK_ATTR: return luaH_dom_element_push_attribute_table(L);
        default:
            return 0;
    }
}

void
dom_element_class_setup(lua_State *L)
{
    static const struct luaL_reg dom_element_methods[] =
    {
        LUA_CLASS_METHODS(dom_element)
        { NULL, NULL }
    };

    static const struct luaL_reg dom_element_meta[] =
    {
        LUA_OBJECT_META(dom_element)
        { "__index", luaH_dom_element_index },
        { "__gc", luaH_dom_element_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &dom_element_class, "dom_element",
            (lua_class_allocator_t) dom_element_new,
            NULL, NULL,
            dom_element_methods, dom_element_meta);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
