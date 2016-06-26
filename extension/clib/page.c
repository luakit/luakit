#include "extension/extension.h"
#include "extension/clib/page.h"
#include "common/tokenize.h"
#include "common/luautil.h"
#include "common/luauniq.h"
#include "common/luajs.h"
#include "luah.h"

#define REG_KEY "luakit.uniq.registry.page"

LUA_OBJECT_FUNCS(page_class, page_t, page);

static gboolean
send_request_cb(WebKitWebPage *web_page, WebKitURIRequest *request,
        WebKitURIResponse *UNUSED(redirected_response), page_t *UNUSED(page))
{
    lua_State *L = extension.WL;
    const gchar *uri = webkit_uri_request_get_uri(request);

    luaH_uniq_get_ptr(L, REG_KEY, web_page);
    lua_pushstring(L, uri);
    gint ret = luaH_object_emit_signal(L, -2, "send-request", 1, 1);

    if (ret) {
        if (lua_isstring(L, -1)) /* redirect */
            webkit_uri_request_set_uri(request, lua_tostring(L, -1));
        else if (!lua_toboolean(L, -1)) { /* block request */
            lua_pop(L, ret + 1);
            return TRUE;
        }
    }

    lua_pop(L, ret + 1);
    return FALSE;
}

static void
document_loaded_cb(WebKitWebPage *web_page, page_t *UNUSED(page))
{
    lua_State *L = extension.WL;
    luaH_uniq_get_ptr(L, REG_KEY, web_page);
    luaH_object_emit_signal(L, -1, "document-loaded", 0, 0);
    lua_pop(L, 1);
}

static gint
luaH_page_eval_js(lua_State *L)
{
    page_t *page = luaH_checkudata(L, 1, &page_class);
    const gchar *script = luaL_checkstring(L, 2);
    const gchar *source = NULL;

    gint top = lua_gettop(L);
    if (top >= 3 && !lua_isnil(L, 3)) {
        luaH_checktable(L, 3);
        if (luaH_rawfield(L, 3, "source"))
            source = luaL_checkstring(L, -1);
        lua_settop(L, top);
    }

    source = source ?: luaH_callerinfo(L);

    WebKitFrame *frame = webkit_web_page_get_main_frame(page->page);
    WebKitScriptWorld *world = extension.script_world;
    JSGlobalContextRef ctx = webkit_frame_get_javascript_context_for_script_world(frame, world);
    return luaJS_eval_js(extension.WL, ctx, script, source, false);
}

static inline void
luaH_page_destroy_cb(WebKitWebPage *web_page)
{
    lua_State *L = extension.WL;
    lua_pushlightuserdata(L, web_page);
    luaH_uniq_del(L, REG_KEY, -1);
    lua_pop(L, 1);
}

gint
luaH_page_from_web_page(lua_State *L, WebKitWebPage *web_page)
{
    if (luaH_uniq_get_ptr(L, REG_KEY, web_page))
        return 1;

    lua_newtable(L);
    luaH_class_new(L, &page_class);
    lua_remove(L, -2);

    page_t *page = luaH_checkudata(L, -1, &page_class);
    page->page = web_page;

    g_signal_connect(page->page, "send-request", G_CALLBACK(send_request_cb), page);
    g_signal_connect(page->page, "document-loaded", G_CALLBACK(document_loaded_cb), page);

    luaH_bind_gobject_ref(L, web_page, -1);
    luaH_uniq_add_ptr(L, REG_KEY, web_page, -1);
    g_object_set_data_full(G_OBJECT(web_page), "page-dummy-destroy-notify", web_page,
            (GDestroyNotify)luaH_page_destroy_cb);

    return 1;
}

static int
luaH_page_new(lua_State *L)
{
    guint64 page_id = luaL_checknumber(L, -1);
    WebKitWebPage *page = webkit_web_extension_get_page(extension.ext, page_id);
    return luaH_page_from_web_page(L, page);
}

static gint
luaH_page_index(lua_State *L)
{
    const char *prop = luaL_checkstring(L, 2);

    if(luaH_usemetatable(L, 1, 2))
        return 1;

    page_t *page = luaH_checkudata(L, 1, &page_class);
    luakit_token_t token = l_tokenize(prop);

    switch(token) {
        PS_CASE(URI, webkit_web_page_get_uri(page->page));
        PI_CASE(ID, webkit_web_page_get_id(page->page));
        PF_CASE(EVAL_JS, luaH_page_eval_js)
        default:
            return 0;
    }
}

void
page_class_setup(lua_State *L)
{
    static const struct luaL_reg page_methods[] =
    {
        LUA_CLASS_METHODS(page)
        { "__call", luaH_page_new },
        { NULL, NULL }
    };

    static const struct luaL_reg page_meta[] =
    {
        LUA_OBJECT_META(page)
        { "__index", luaH_page_index },
        { "__gc", luaH_object_gc },
        { NULL, NULL }
    };

    luaH_class_setup(L, &page_class, "page",
            (lua_class_allocator_t) page_new,
            NULL, NULL,
            page_methods, page_meta);

    luaH_uniq_setup(L, REG_KEY);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
