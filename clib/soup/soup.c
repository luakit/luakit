/*
 * clib/soup/soup.c - soup library
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

#include "clib/soup/soup.h"
#include "common/property.h"
#include "common/signal.h"

#include <libsoup/soup.h>
#include <webkit/webkit.h>

/* setup soup module signals */
LUA_CLASS_FUNCS(soup, soup_class);

property_t soup_properties[] = {
  { L_TK_ACCEPT_LANGUAGE,      "accept-language",      CHAR, TRUE },
  { L_TK_ACCEPT_LANGUAGE_AUTO, "accept-language-auto", BOOL, TRUE },
  { L_TK_IDLE_TIMEOUT,         "idle-timeout",         INT,  TRUE },
  { L_TK_MAX_CONNS,            "max-conns",            INT,  TRUE },
  { L_TK_MAX_CONNS_PER_HOST,   "max-conns-per-host",   INT,  TRUE },
  { L_TK_PROXY_URI,            "proxy-uri",            URI,  TRUE },
  { L_TK_SSL_CA_FILE,          "ssl-ca-file",          CHAR, TRUE },
  { L_TK_SSL_STRICT,           "ssl-strict",           BOOL, TRUE },
  { L_TK_TIMEOUT,              "timeout",              INT,  TRUE },
  { 0,                         NULL,                   0,    0    },
};

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

gint
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
    if (!str[0] || !g_strcmp0(str, "about:blank"))
        return 0;

    /* default to http:// scheme */
    if (!g_strrstr(str, "://"))
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

static gint
luaH_soup_index(lua_State *L)
{
    if (!lua_isstring(L, 2))
        return 0;

    return luaH_gobject_index(L, soup_properties,
            l_tokenize(lua_tostring(L, 2)),
            G_OBJECT(soupconf.session));
}

static gint
luaH_soup_newindex(lua_State *L)
{
    if (!lua_isstring(L, 2))
        return 0;

    luakit_token_t token = l_tokenize(lua_tostring(L, 2));

    if (token == L_TK_ACCEPT_POLICY) {
        g_object_set(G_OBJECT(soupconf.cookiejar), "accept-policy",
                (gint)luaL_checknumber(L, 3), NULL);
        return luaH_class_property_signal(L, &soup_class, token);
    }

    if (luaH_gobject_newindex(L, soup_properties, token, 3,
                G_OBJECT(soupconf.session)))
        return luaH_class_property_signal(L, &soup_class, token);

    return 0;
}

void
soup_lib_setup(lua_State *L)
{
    static const struct luaL_reg soup_lib[] =
    {
        LUA_CLASS_METHODS(soup)
        { "__index",       luaH_soup_index },
        { "__newindex",    luaH_soup_newindex },
        { "parse_uri",     luaH_soup_parse_uri },
        { "uri_tostring",  luaH_soup_uri_tostring },
        { "add_cookies",   luaH_cookiejar_add_cookies },
        { NULL,            NULL },
    };

    /* create signals array */
    soup_class.signals = signal_new();

    /* init soup struct */
    soupconf.cookiejar = luakit_cookie_jar_new();
    soupconf.session = webkit_get_default_session();
    soup_session_add_feature(soupconf.session,
            (SoupSessionFeature*) soupconf.cookiejar);

    /* remove old auth dialog and add luakit's auth feature instead */
    soup_session_remove_feature_by_type(soupconf.session,
            WEBKIT_TYPE_SOUP_AUTH_DIALOG);
    soup_session_add_feature(soupconf.session,
            (SoupSessionFeature*) luakit_auth_dialog_new());

    /* export soup lib */
    luaH_openlib(L, "soup", soup_lib, soup_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
