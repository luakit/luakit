/*
 * widgets/webview/inspector.c - WebKitWebInspector wrappers
 *
 * Copyright © 2012 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2011-2012 Fabian Streitel <karottenreibe@gmail.com>
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

static WebKitWebView*
inspect_webview_cb(WebKitWebInspector *UNUSED(inspector), WebKitWebView *UNUSED(v), widget_t *w)
{
    lua_State *L = globalconf.L;
    webview_data_t *d = w->data;
    luaH_object_push(L, w->ref);

    if (luaH_object_emit_signal(L, -1, "create-inspector-web-view", 0, 1)) {
        widget_t *new;
        if (((new = luaH_towidget(L, -1)) && new->info->tok == L_TK_WEBVIEW)) {
            d->iview = new;
            lua_pop(L, 2);
            return ((webview_data_t*)new->data)->view;
        }
        warn("invalid signal return type (expected webview widget, got %s)",
                lua_typename(L, lua_type(L, -1)));
    }
    lua_pop(L, 1);
    return NULL;
}

static gboolean
inspector_show_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "show-inspector", 0, 0);
    lua_pop(L, 1);
    return TRUE;
}

static gboolean
inspector_close_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    webview_data_t *d = w->data;
    luaH_object_push(L, d->iview);
    d->iview = NULL;
    luaH_object_emit_signal(L, -2, "close-inspector", 1, 0);
    lua_pop(L, 1);
    return TRUE;
}

static gboolean
inspector_attach_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "attach-inspector", 0, 0);
    lua_pop(L, 1);
    return TRUE;
}

static gboolean
inspector_detach_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = globalconf.L;
    luaH_object_push(L, w->ref);
    luaH_object_emit_signal(L, -1, "detach-inspector", 0, 0);
    lua_pop(L, 1);
    return TRUE;
}

static gint
luaH_webview_show_inspector(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_inspector_show(d->inspector);
    return 0;
}

static gint
luaH_webview_close_inspector(lua_State *L)
{
    webview_data_t *d = luaH_checkwvdata(L, 1);
    webkit_web_inspector_close(d->inspector);
    return 0;
}
