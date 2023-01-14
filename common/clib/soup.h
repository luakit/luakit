/*
 * common/clib/soup.h - soup library
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
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

#ifndef LUAKIT_COMMON_CLIB_SOUP_H
#define LUAKIT_COMMON_CLIB_SOUP_H

#include <libsoup/soup-version.h>
#if SOUP_CHECK_VERSION(3,0,0)
#include <libsoup/soup-uri-utils.h>
#else
#include <libsoup/soup-uri.h>
#define SOUP_HTTP_URI_FLAGS (G_URI_FLAGS_HAS_PASSWORD     |\
                             G_URI_FLAGS_ENCODED_PATH     |\
                             G_URI_FLAGS_ENCODED_QUERY    |\
                             G_URI_FLAGS_ENCODED_FRAGMENT |\
                             G_URI_FLAGS_SCHEME_NORMALIZE)
#endif


static GRegex *scheme_reg;

static gint
luaH_soup_uri_tostring(lua_State *L)
{
    const gchar *p;
    gint port;
    /* check for uri table */
    luaH_checktable(L, 1);
    const gchar * scheme   = NULL;
    const gchar * user     = NULL;
    const gchar * host     = NULL;
    const gchar * path     = NULL;
    const gchar * query    = NULL;
    const gchar * fragment = NULL;
    gchar * uri;

#define GET_PROP(prop)                                          \
    lua_pushliteral(L, #prop);                                  \
    lua_rawget(L, 1);                                           \
    if (!lua_isnil(L, -1) && (p = lua_tostring(L, -1)) && p[0]) \
        prop = p;                                               \
    lua_pop(L, 1);

    GET_PROP(scheme)

    /* If this is a file:// uri, set a default host of ""
     * Without host set, a path of "/home/..." will become "file:/home/..."
     * instead of "file:///home/..."
     */
    if (!g_strcmp0(scheme, "file"))
        host = ""; // I assume that this is strdup()ed by g_uri_join(),
                   // so use some space on the stack rather than calloc()ing.

    GET_PROP(user)
    GET_PROP(host)
    GET_PROP(path)
    GET_PROP(query)
    GET_PROP(fragment)

    lua_pushliteral(L, "port");
    lua_rawget(L, 1);
    if (lua_isnil(L, -1) || !(port = lua_tonumber(L, -1)))
        port = -1; // g_uri_* use -1 if the port is absent.
    lua_pop(L, 1);

    uri = g_uri_join_with_user (SOUP_HTTP_URI_FLAGS,
                                scheme,
                                user,
                                NULL,  // password. Omitted to retain soup_uri_to_string()'s behaviour
                                NULL,  // auth_params, whatever they are.
                                host,
                                port,
                                path,
                                query,
                                fragment);

    lua_pushstring(L, uri);
    g_free(uri);
    // Lua will clean up the `gchar*`s returned by lua_tostring().

    return 1;
}

static gint
luaH_soup_push_uri(lua_State *L, GUri *uri)
{
    const gchar *p;
    gint port;
    /* create table for uri properties */
    lua_newtable(L);

#define PUSH_PROP(prop)                        \
    if ((p = g_uri_get_##prop(uri)) && p[0]) { \
        lua_pushliteral(L, #prop);             \
        lua_pushstring(L, p);                  \
        lua_rawset(L, -3);                     \
    }

    PUSH_PROP(scheme)
    PUSH_PROP(user)
    PUSH_PROP(password)
    PUSH_PROP(host)
    PUSH_PROP(path)
    PUSH_PROP(query)
    PUSH_PROP(fragment)

    port = g_uri_get_port(uri);
    if (port > 0) { // g_uri_* use -1 if the port is absent.
        lua_pushliteral(L, "port");
        lua_pushnumber(L, port);
        lua_rawset(L, -3);
    }

    return 1;
}

static gint
luaH_soup_parse_uri(lua_State *L)
{
    gchar *str = (gchar*)luaL_checkstring(L, 1);

    /* check for blank uris */
    if (!str[0])
        return 0;

    /* default to http:// scheme */
    if (!g_regex_match(scheme_reg, str, 0, 0))
        str = g_strdup_printf("http://%s", str);
    else
        str = g_strdup(str);

    /* parse & push uri */
    GUri *uri = g_uri_parse (str, SOUP_HTTP_URI_FLAGS, NULL);
    g_free(str);
    if (uri) {
        luaH_soup_push_uri(L, uri);
        g_uri_unref(uri);
        return 1;
    }
    return 0;
}

static void
soup_lib_setup_common(void)
{
    scheme_reg = g_regex_new("^[a-z][a-z0-9\\+\\-\\.]*:", G_REGEX_OPTIMIZE, 0, NULL);
}

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
