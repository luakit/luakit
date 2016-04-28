#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "common/tokenize.h"

LUA_OBJECT_FUNCS(dom_document_class, dom_document_t, dom_document);

gint
luaH_dom_document_from_web_page(lua_State *L, WebKitWebPage *web_page)
{
    lua_newtable(L);
    luaH_class_new(L, &dom_document_class);
    lua_remove(L, -2);

    dom_document_t *document = luaH_checkudata(L, -1, &dom_document_class);
    document->document = webkit_web_page_get_dom_document(web_page);

    return 1;
}

static gint
luaH_dom_document_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_document_push_body(lua_State *L, dom_document_t *document)
{
    lua_newtable(L);
    luaH_class_new(L, &dom_element_class);
    dom_element_t *element = luaH_checkudata(L, -1, &dom_element_class);

    element->element = webkit_dom_document_get_body(document->document);

    return 1;
}

static gint
luaH_dom_document_index(lua_State *L)
{
    dom_document_t *document = luaH_checkudata(L, 1, &dom_document_class);
    const char *prop = luaL_checkstring(L, 2);

    if(!strcmp(prop, "body"))
        return luaH_dom_document_push_body(L, document);
    
    return 0;
}

void
dom_document_class_setup(lua_State *L)
{
    static const struct luaL_reg dom_document_methods[] =
    {
        LUA_CLASS_METHODS(dom_document)
        { NULL, NULL }
    };

    static const struct luaL_reg dom_document_meta[] =
    {
        LUA_OBJECT_META(dom_document)
        { "__index", luaH_dom_document_index },
        { "__gc", luaH_dom_document_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &dom_document_class, "dom_document",
            (lua_class_allocator_t) dom_document_new,
            NULL, NULL,
            dom_document_methods, dom_document_meta);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
