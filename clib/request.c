/*
 * clib/request.c - wrapper for the WebKitURISchemeRequest class
 *
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#include "common/luaobject.h"
#include "common/luauniq.h"
#include "clib/request.h"
#include "luah.h"
#include "globalconf.h"
#include "web_context.h"

#include <webkit2/webkit2.h>
#include <glib/gstdio.h>

#define REG_KEY "luakit.uniq.registry.request"

typedef struct {
    LUA_OBJECT_HEADER
    WebKitURISchemeRequest *request;
    gboolean finished;
} request_t;

static lua_class_t request_class;
LUA_OBJECT_FUNCS(request_class, request_t, request)

static request_t*
luaH_check_request(lua_State *L, gint idx)
{
    request_t *request = luaH_checkudata(L, idx, &(request_class));
    if (request->finished)
        luaL_error(L, "request has already been finished");
    return request;
}

gint
luaH_request_push_uri_scheme_request(lua_State *L, WebKitURISchemeRequest *r)
{
    if (luaH_uniq_get_ptr(L, REG_KEY, r))
        return 1;

    request_t *request = request_new(L);
    request->request = g_object_ref(r);
    request->finished = FALSE;

    luaH_uniq_add_ptr(L, REG_KEY, r, -1);

    return 1;
}

static gint
luaH_request_finish(lua_State *L)
{
    request_t *request = luaH_check_request(L, 1);
    request->finished = TRUE;

    /* Argument errors cause direct termination of the request */
    const gchar *error_message;
    if (!lua_isstring(L, 2)) {
        error_message = "data isn't a string";
        goto error;
    }
    if (lua_type(L, 3) == LUA_TNONE)
        lua_pushnil(L);
    if ((lua_type(L, 3) != LUA_TSTRING) && (lua_type(L, 3) != LUA_TNIL)) {
        error_message = "MIME type isn't a string or nil";
        goto error;
    }

    size_t length;
    const gchar *data = lua_tolstring(L, 2, &length);
    const gchar *mime = lua_tostring(L, 3) ?: "text/html";
    GInputStream *stream = g_memory_input_stream_new_from_data(g_memdup(data, length), length, g_free);
    webkit_uri_scheme_request_finish(request->request, stream, length, mime);
    g_object_unref(stream);

    return 0;
error:
    g_assert(error_message);
    GError *error = g_error_new_literal(g_quark_from_static_string("luakit"),
            0, error_message);
    webkit_uri_scheme_request_finish_error(request->request, error);
    return luaL_error(L, error_message);
}

static int
luaH_request_get_finished(lua_State *L, request_t *request)
{
    lua_pushboolean(L, request->finished);
    return 1;
}

void
request_class_setup(lua_State *L)
{
    static const struct luaL_Reg request_methods[] =
    {
        LUA_CLASS_METHODS(request)
        { NULL, NULL }
    };

    static const struct luaL_Reg request_meta[] =
    {
        LUA_OBJECT_META(request)
        LUA_CLASS_META
        { "finish", luaH_request_finish },
        { NULL, NULL },
    };

    luaH_class_setup(L, &request_class, "request",
             (lua_class_allocator_t) request_new,
             NULL, NULL,
             request_methods, request_meta);

    luaH_class_add_property(&request_class, L_TK_FINISHED,
            NULL, (lua_class_propfunc_t) luaH_request_get_finished, NULL);

    luaH_uniq_setup(L, REG_KEY, "");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
