#define WEBKIT_DOM_USE_UNSTABLE_API
#include <webkitdom/WebKitDOMDOMWindowUnstable.h>

#include "extension/extension.h"
#include "extension/clib/dom_document.h"
#include "extension/clib/dom_element.h"
#include "common/tokenize.h"

LUA_OBJECT_FUNCS(dom_document_class, dom_document_t, dom_document);

gint
luaH_dom_document_from_webkit_dom_document(lua_State *L, WebKitDOMDocument *doc)
{
    lua_newtable(L);
    luaH_class_new(L, &dom_document_class);
    lua_remove(L, -2);

    dom_document_t *document = lua_touserdata(L, -1);
    document->document = doc;

    return 1;
}

gint
luaH_dom_document_from_web_page(lua_State *L, WebKitWebPage *web_page)
{
    WebKitDOMDocument *doc = webkit_web_page_get_dom_document(web_page);
    return luaH_dom_document_from_webkit_dom_document(L, doc);
}

static int
luaH_dom_document_new(lua_State *L)
{
    guint64 page_id = luaL_checknumber(L, -1);
    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    return luaH_dom_document_from_web_page(L, page);
}

static gint
luaH_dom_document_gc(lua_State *L)
{
    return luaH_object_gc(L);
}

static gint
luaH_dom_document_push_body(lua_State *L, dom_document_t *document)
{
    WebKitDOMHTMLElement* node = webkit_dom_document_get_body(document->document);
    return luaH_dom_element_from_node(L, WEBKIT_DOM_ELEMENT(node));
}

static gint
luaH_dom_document_window_index(lua_State *L)
{
    dom_document_t *document = luaH_checkudata(L, lua_upvalueindex(1), &dom_document_class);
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    WebKitDOMDOMWindow *window = webkit_dom_document_get_default_view(document->document);

    switch (token) {
        PI_CASE(SCROLL_X, webkit_dom_dom_window_get_scroll_x(window));
        PI_CASE(SCROLL_Y, webkit_dom_dom_window_get_scroll_y(window));
        PI_CASE(INNER_WIDTH, webkit_dom_dom_window_get_inner_width(window));
        PI_CASE(INNER_HEIGHT, webkit_dom_dom_window_get_inner_height(window));
        default:
            return 0;
    }
}

static gint
luaH_dom_document_push_window_table(lua_State *L)
{
    /* create attribute table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy element userdata */
    lua_pushcclosure(L, luaH_dom_document_window_index, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static gint
luaH_dom_document_create_element(lua_State *L)
{
    dom_document_t *document = luaH_checkudata(L, 1, &dom_document_class);
    const char *tagname = luaL_checkstring(L, 2);
    GError *error = NULL;

    WebKitDOMElement *elem = webkit_dom_document_create_element(document->document, tagname, &error);

    if (error)
        return luaL_error(L, "create element error: %s", error->message);

    /* Set all attributes */
    if (lua_istable(L, 3)) {
        lua_pushnil(L);
        while (lua_next(L, 3) != 0) {
            const char *name = luaL_checkstring(L, -2);
            const char *value = luaL_checkstring(L, -1);
            webkit_dom_element_set_attribute(elem, name, value, &error);
            lua_pop(L, 1);

            if (error)
                return luaL_error(L, "set new element attribute error: %s", error->message);
        }
    }

    /* Set inner text */
    if (lua_isstring(L, 4)) {
        const char *inner_text = lua_tostring(L, 4);
        webkit_dom_html_element_set_inner_text(WEBKIT_DOM_HTML_ELEMENT(elem), inner_text, NULL);
    }

    return luaH_dom_element_from_node(L, elem);
}

static gint
luaH_dom_document_element_from_point(lua_State *L)
{
    dom_document_t *document = luaH_checkudata(L, 1, &dom_document_class);
    glong x = luaL_checknumber(L, 2),
          y = luaL_checknumber(L, 3);

    WebKitDOMElement *elem = webkit_dom_document_element_from_point(document->document, x, y);

    return luaH_dom_element_from_node(L, elem);
}

static gint
luaH_dom_document_index(lua_State *L)
{
    dom_document_t *document = luaH_checkudata(L, 1, &dom_document_class);
    const char *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {
        PF_CASE(CREATE_ELEMENT, luaH_dom_document_create_element);
        PF_CASE(ELEMENT_FROM_POINT, luaH_dom_document_element_from_point);
        case L_TK_BODY: return luaH_dom_document_push_body(L, document);
        case L_TK_WINDOW: return luaH_dom_document_push_window_table(L);
        default:
            return 0;
    }
}

void
dom_document_class_setup(lua_State *L)
{
    static const struct luaL_reg dom_document_methods[] =
    {
        LUA_CLASS_METHODS(dom_document)
        { "__call", luaH_dom_document_new },
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
