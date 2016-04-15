#include <webkitdom/webkitdom.h>

#include "extension/clib/dom_element.h"

LUA_OBJECT_FUNCS(dom_element_class, dom_element_t, dom_element);

static gint
luaH_dom_element_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_element_index(lua_State *L)
{
    dom_element_t *element = luaH_checkudata(L, 1, &dom_element_class);
    const char *prop = luaL_checkstring(L, 2);

    if(!strcmp(prop, "id")) {
        lua_pushstring(L, webkit_dom_element_get_attribute((WebKitDOMElement*)(element->element), "id"));
        return 1;
    }
    
    return 0;
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
