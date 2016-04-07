#if WITH_WEBKIT2

guint
stylesheet_add(const gchar *source)
{
    WebKitUserStyleSheet *stylesheet = webkit_user_style_sheet_new(source,
            WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES, WEBKIT_USER_STYLE_LEVEL_USER, NULL, NULL);
    g_ptr_array_add(globalconf.stylesheets, stylesheet);
    return globalconf.stylesheets->len - 1;
}

int
webview_stylesheet_set_enabled(widget_t *w, guint id, gboolean enable)
{
    if (id >= globalconf.stylesheets->len)
        return 1;

    webview_data_t *d = w->data;

    GList *item = g_list_find(d->stylesheets, GUINT_TO_POINTER(id));

    /* Return early if nothing to do */
    if (enable == (item != NULL))
        return 0;

    if (enable) {
        d->stylesheets = g_list_prepend(d->stylesheets, GUINT_TO_POINTER(id));
        WebKitUserStyleSheet *stylesheet = globalconf.stylesheets->pdata[id];
        webkit_user_content_manager_add_style_sheet(d->user_content, stylesheet);
    } else {
        d->stylesheets = g_list_remove_link(d->stylesheets, item);

        webkit_user_content_manager_remove_all_style_sheets(d->user_content);

        GList *l;
        for (l = d->stylesheets; l; l = l->next) {
            guint l_id = GPOINTER_TO_UINT(l->data);
            WebKitUserStyleSheet *stylesheet = globalconf.stylesheets->pdata[l_id];
            webkit_user_content_manager_add_style_sheet(d->user_content, stylesheet);
        }
    }

    return 0;
}

static gint
luaH_webview_stylesheets_index(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    guint id = luaL_checknumber(L, 2);

    printf("Looking up stylesheet %u status...\n", id);

    gboolean enabled = g_list_find(d->stylesheets, GUINT_TO_POINTER(id)) != NULL;
    lua_pushboolean(L, enabled);

    return 1;
}

static gint
luaH_webview_stylesheets_newindex(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, lua_upvalueindex(1));
    guint id = luaL_checknumber(L, 2);
    gboolean enable = lua_toboolean(L, 3);

    webview_stylesheet_set_enabled(d->widget, id,  enable);

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

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
