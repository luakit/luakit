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
luaH_dom_element_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMElement *elem = WEBKIT_DOM_ELEMENT(element->element);

    switch(token) {
        PS_CASE(ID, webkit_dom_element_get_attribute(elem, "id"))
        PF_CASE(QUERY, luaH_dom_element_query)
        PF_CASE(APPEND, luaH_dom_element_append)
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
