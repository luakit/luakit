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

static GRegex *scheme_reg;

static gint
luaH_soup_uri_tostring(lua_State *L)
{
    const gchar *p;
    gint port;
    /* check for uri table */
    luaH_checktable(L, 1);
    /* create empty soup uri object */
    SoupURI *uri = soup_uri_new(NULL);
    soup_uri_set_scheme(uri, "http");

#define GET_PROP(prop)                                          \
    lua_pushliteral(L, #prop);                                  \
    lua_rawget(L, 1);                                           \
    if (!lua_isnil(L, -1) && (p = lua_tostring(L, -1)) && p[0]) \
        soup_uri_set_##prop(uri, p);                            \
    lua_pop(L, 1);

    GET_PROP(scheme)

    /* If this is a file:// uri, set a default host of ""
     * Without host set, a path of "/home/..." will become "file:/home/..."
     * instead of "file:///home/..."
     */
    if (soup_uri_get_scheme(uri) == SOUP_URI_SCHEME_FILE) {
        soup_uri_set_host(uri, "");
    }

    GET_PROP(user)
    GET_PROP(password)
    GET_PROP(host)
    GET_PROP(path)
    GET_PROP(query)
    GET_PROP(fragment)

    lua_pushliteral(L, "port");
    lua_rawget(L, 1);
    if (!lua_isnil(L, -1) && (port = lua_tonumber(L, -1)))
        soup_uri_set_port(uri, port);
    lua_pop(L, 1);

    gchar *str = soup_uri_to_string(uri, FALSE);
    lua_pushstring(L, str);
    g_free(str);
    soup_uri_free(uri);
    return 1;
}

static gint
luaH_soup_push_uri(lua_State *L, SoupURI *uri)
{
    const gchar *p;
    /* create table for uri properties */
    lua_newtable(L);

#define PUSH_PROP(prop)            \
    if ((p = uri->prop) && p[0]) { \
        lua_pushliteral(L, #prop); \
        lua_pushstring(L, p);      \
        lua_rawset(L, -3);         \
    }

    PUSH_PROP(scheme)
    PUSH_PROP(user)
    PUSH_PROP(password)
    PUSH_PROP(host)
    PUSH_PROP(path)
    PUSH_PROP(query)
    PUSH_PROP(fragment)

    if (uri->port) {
        lua_pushliteral(L, "port");
        lua_pushnumber(L, uri->port);
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
    SoupURI *uri = soup_uri_new(str);
    g_free(str);
    if (uri) {
        luaH_soup_push_uri(L, uri);
        soup_uri_free(uri);
    }
    return uri ? 1 : 0;
}

static void
soup_lib_setup_common(void)
{
    scheme_reg = g_regex_new("^[a-z][a-z0-9\\+\\-\\.]*:", G_REGEX_OPTIMIZE, 0, NULL);
}

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
