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
    /* create empty(ish) uri object */
    GUri * uri = g_uri_parse ("http://", SOUP_HTTP_URI_FLAGS, NULL);
    GUri * old_uri = NULL;

#define GET_PROP(prop,PROP)                                              \
    lua_pushliteral(L, #prop);                                           \
    lua_rawget(L, 1);                                                    \
    if (!lua_isnil(L, -1) && (p = lua_tostring(L, -1)) && p[0]) {         \
        old_uri = uri;                                                   \
        uri = soup_uri_copy(old_uri, SOUP_URI_##PROP, p, SOUP_URI_NONE); \
        g_free(old_uri);                                                 \
    }                                                                    \
    lua_pop(L, 1);

    GET_PROP(scheme, SCHEME)

    /* If this is a file:// uri, set a default host of ""
     * Without host set, a path of "/home/..." will become "file:/home/..."
     * instead of "file:///home/..."
     */
    if (!g_strcmp0(g_uri_get_scheme(uri), "file")) {
        uri = soup_uri_copy(uri, SOUP_URI_HOST, "", SOUP_URI_NONE);
    }

    GET_PROP(user, USER)
    GET_PROP(password, PASSWORD)
    GET_PROP(host, HOST)
    GET_PROP(path, PATH)
    GET_PROP(query, QUERY)
    GET_PROP(fragment, FRAGMENT)

    lua_pushliteral(L, "port");
    lua_rawget(L, 1);
    if (!lua_isnil(L, -1) && (port = lua_tonumber(L, -1))) {
        old_uri = uri;
        uri = soup_uri_copy(old_uri, SOUP_URI_PORT, port, SOUP_URI_NONE);
        g_free(old_uri);
    }
    lua_pop(L, 1);

    gchar *str = g_uri_to_string(uri);
    lua_pushstring(L, str);
    g_free(str);
    g_free(uri);  // GUri is a `struct _GUri` rather than a gobject,
                  // so i'm guessing it should be `g_free`d rather than `g_object_unref`fed

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

    if ((port = g_uri_get_port(uri))) {
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
        //g_free(uri);  // This free crashes with a double-free.
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
