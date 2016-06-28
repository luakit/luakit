#include "clib/stylesheet.h"

void
webview_stylesheets_regenerate_stylesheet(widget_t *w, lstylesheet_t *stylesheet) {
    webview_data_t *d = w->data;

    /* If this styleheet was enabled, it needs to be re-added to the user
     * content manager, since its internal WebKitUserStyleSheet pointer has
     * changed: mark for refresh */
    if (g_list_find(d->stylesheets, stylesheet))
        d->stylesheet_refreshed = TRUE;
}

void
webview_stylesheets_regenerate(widget_t *w) {
    webview_data_t *d = w->data;

    /* Re-add the user content manager stylesheets, if necessary */

    if (d->stylesheet_removed || d->stylesheet_refreshed)
        webkit_user_content_manager_remove_all_style_sheets(d->user_content);

    if (d->stylesheet_added || d->stylesheet_removed || d->stylesheet_refreshed) {
        GList *l;
        for (l = d->stylesheets; l; l = l->next) {
            lstylesheet_t *stylesheet = l->data;
            webkit_user_content_manager_add_style_sheet(d->user_content, stylesheet->stylesheet);
        }
    }
}

int
webview_stylesheet_set_enabled(widget_t *w, lstylesheet_t *stylesheet, gboolean enable)
{
    webview_data_t *d = w->data;
    GList *item = g_list_find(d->stylesheets, stylesheet);

    /* Return early if nothing to do */
    if (enable == (item != NULL))
        return 0;

    if (enable) {
        d->stylesheets = g_list_prepend(d->stylesheets, stylesheet);
        d->stylesheet_added = TRUE;
    } else {
        d->stylesheets = g_list_remove_link(d->stylesheets, item);
        d->stylesheet_removed = TRUE;
    }

    return 0;
}

static gint
luaH_webview_stylesheets_index(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    lstylesheet_t *stylesheet = luaH_checkstylesheet(L, 2);

    gboolean enabled = g_list_find(d->stylesheets, stylesheet) != NULL;
    lua_pushboolean(L, enabled);

    return 1;
}

static gint
luaH_webview_stylesheets_newindex(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    lstylesheet_t *stylesheet = luaH_checkstylesheet(L, 2);
    gboolean enable = lua_toboolean(L, 3);

    webview_stylesheet_set_enabled(d->widget, stylesheet,  enable);

    return 0;
}

static gint
luaH_webview_push_stylesheets_table(lua_State *L)
{
    /* create scroll table */
    lua_newtable(L);
    /* setup metatable */
    lua_createtable(L, 0, 2);
    /* push __index metafunction */
    lua_pushliteral(L, "__index");
    lua_pushvalue(L, 1); /* copy webview userdata */
    lua_pushcclosure(L, luaH_webview_stylesheets_index, 1);
    lua_rawset(L, -3);
    /* push __newindex metafunction */
    lua_pushliteral(L, "__newindex");
    lua_pushvalue(L, 1); /* copy webview userdata */
    lua_pushcclosure(L, luaH_webview_stylesheets_newindex, 1);
    lua_rawset(L, -3);
    lua_setmetatable(L, -2);
    return 1;
}

static void
webview_update_stylesheets(lua_State *L, widget_t *w)
{
    webview_data_t *d = w->data;

    d->stylesheet_added   = FALSE;
    d->stylesheet_removed = FALSE;

    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "stylesheet", 0, 0);
    lua_pop(L, 1);

    webview_stylesheets_regenerate(w);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
