#include "clib/widget.h"
#include "clib/stylesheet.h"
#include "globalconf.h"
#include "luah.h"

static lua_class_t stylesheet_class;
LUA_OBJECT_FUNCS(stylesheet_class, lstylesheet_t, stylesheet)

gpointer 
luaH_checkstylesheet(lua_State *L, gint idx) {
    return luaH_checkudata(L, idx, &(stylesheet_class));
}

static gint
luaH_stylesheet_new(lua_State *L)
{
    luaH_class_new(L, &stylesheet_class);
    return 1;
}

static void
regenerate_stylesheet(lstylesheet_t *stylesheet)
{
    WebKitUserStyleSheet *old = stylesheet->stylesheet;

    if (old)
        webkit_user_style_sheet_unref(old);

    stylesheet->stylesheet = webkit_user_style_sheet_new(stylesheet->source,
            WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES, WEBKIT_USER_STYLE_LEVEL_USER, NULL, NULL);

    if (old && globalconf.webviews) {
        /* Any web views which had this stylesheet enabled need to be regenerated */
        for (unsigned i=0; i<globalconf.webviews->len; i++) {
            widget_t *w = g_ptr_array_index(globalconf.webviews, i);
            webview_stylesheets_regenerate_stylesheet(w, stylesheet);
        }
    }

}

static int
luaH_stylesheet_set_source(lua_State *L, lstylesheet_t *stylesheet)
{
    const gchar *new_source = luaL_checkstring(L, -1);
    g_free(stylesheet->source);
    stylesheet->source = g_strdup(new_source);

    regenerate_stylesheet(stylesheet);

    return 0;
}

static int
luaH_stylesheet_get_source(lua_State *L, lstylesheet_t *stylesheet)
{
    lua_pushstring(L, stylesheet->source);
    return 1;
}

void
stylesheet_class_setup(lua_State *L)
{
    static const struct luaL_reg stylesheet_methods[] =
    {
        LUA_CLASS_METHODS(stylesheet)
        { "__call", luaH_stylesheet_new },
        { NULL, NULL }
    };

    static const struct luaL_reg stylesheet_meta[] =
    {
        LUA_OBJECT_META(stylesheet)
        LUA_CLASS_META
        { "__gc", luaH_object_gc },
        { NULL, NULL },
    };

    luaH_class_setup(L, &stylesheet_class, "stylesheet",
            (lua_class_allocator_t) stylesheet_new,
            luaH_class_index_miss_property, luaH_class_newindex_miss_property,
            stylesheet_methods, stylesheet_meta);

    luaH_class_add_property(&stylesheet_class, L_TK_SOURCE,
            (lua_class_propfunc_t) luaH_stylesheet_set_source,
            (lua_class_propfunc_t) luaH_stylesheet_get_source,
            (lua_class_propfunc_t) luaH_stylesheet_set_source);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
