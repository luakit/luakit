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

gboolean
inspector_open_window_cb(WebKitWebInspector *UNUSED(inspector), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint nret = luaH_object_emit_signal(L, -1, "create-inspector-window", 0, 1);
    gboolean ret = nret && lua_toboolean(L, -1);
    lua_pop(L, 1 + nret);
    return ret;
}

static gboolean
inspector_show_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint nret = luaH_object_emit_signal(L, -1, "show-inspector", 0, 1);
    gboolean ret = nret && lua_toboolean(L, -1);
    lua_pop(L, 1 + nret);
    return ret;
}

static gboolean
inspector_close_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    webview_data_t *d = w->data;
    lua_pushnil(L);
    d->inspector_open = FALSE;
    gint nret = luaH_object_emit_signal(L, -2, "close-inspector", 1, 0);
    gboolean ret = nret && lua_toboolean(L, -1);
    lua_pop(L, 1 + nret);
    return ret;
}

static gboolean
inspector_attach_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = common.L;
    webview_data_t *d = w->data;
    d->inspector_open = TRUE;
    luaH_object_push(L, w->ref);
    gint nret = luaH_object_emit_signal(L, -1, "attach-inspector", 0, 0);
    gboolean ret = nret && lua_toboolean(L, -1);
    lua_pop(L, 1 + nret);
    return ret;
}

static gboolean
inspector_detach_window_cb(WebKitWebInspector* UNUSED(inspector), widget_t *w)
{
    lua_State *L = common.L;
    luaH_object_push(L, w->ref);
    gint nret = luaH_object_emit_signal(L, -1, "detach-inspector", 0, 0);
    gboolean ret = nret && lua_toboolean(L, -1);
    lua_pop(L, 1 + nret);
    return ret;
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

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
