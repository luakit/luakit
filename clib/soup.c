/*
 * clib/soup.c - soup library
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

#include "clib/soup.h"
#include "common/property.h"
#include "common/signal.h"
#include "web_context.h"

#include <libsoup/soup.h>
#include <webkit2/webkit2.h>

static gchar *proxy_uri;
static GRegex *scheme_reg;
/* lua soup class for signals */
static lua_class_t soup_class;
static gchar *accept_policy;

/* setup soup module signals */
LUA_CLASS_FUNCS(soup, soup_class);

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

#if WEBKIT_CHECK_VERSION(2,16,0)
static gint
luaH_soup_index(lua_State *L)
{
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch (token) {
        PS_CASE(PROXY_URI, proxy_uri)
        PS_CASE(ACCEPT_POLICY, accept_policy)
        default:
            break;
    }
    return 0;
}

static void
luaH_soup_set_accept_policy(lua_State *L)
{
    const gchar *new_policy = luaL_checkstring(L, 3);
    if (!g_str_equal(new_policy, "always"))
    if (!g_str_equal(new_policy, "never"))
    if (!g_str_equal(new_policy, "no_third_party"))
        luaL_error(L, "accept_policy must be one of 'always', 'never', 'no_third_party'");
    g_free(accept_policy);
    accept_policy = g_strdup(new_policy);

    WebKitWebContext * web_context = web_context_get();
    WebKitCookieManager *cookie_mgr = webkit_web_context_get_cookie_manager(web_context);
    WebKitCookieAcceptPolicy policy;
    if (g_str_equal(new_policy, "always"))
        policy = WEBKIT_COOKIE_POLICY_ACCEPT_ALWAYS;
    else if (g_str_equal(new_policy, "never"))
        policy = WEBKIT_COOKIE_POLICY_ACCEPT_NEVER;
    else if (g_str_equal(new_policy, "no_third_party"))
        policy = WEBKIT_COOKIE_POLICY_ACCEPT_NO_THIRD_PARTY;
    else g_assert_not_reached();
    webkit_cookie_manager_set_accept_policy(cookie_mgr, policy);
}

static gint
luaH_soup_newindex(lua_State *L)
{
    const gchar *prop = luaL_checkstring(L, 2);
    luakit_token_t token = l_tokenize(prop);

    switch (token) {
        case L_TK_PROXY_URI: {
            WebKitWebContext *ctx = web_context_get();
            const gchar *new_proxy_uri = lua_isnil(L, 3) ? "default" : luaL_checkstring(L, 3);
            g_free(proxy_uri);
            proxy_uri = g_strdup(new_proxy_uri);

            if (!proxy_uri || g_str_equal(proxy_uri, "default"))
                webkit_web_context_set_network_proxy_settings(ctx,
                        WEBKIT_NETWORK_PROXY_MODE_DEFAULT, NULL);
            else if (g_str_equal(proxy_uri, "no_proxy"))
                webkit_web_context_set_network_proxy_settings(ctx,
                        WEBKIT_NETWORK_PROXY_MODE_NO_PROXY, NULL);
            else {
                WebKitNetworkProxySettings *proxy_settings = webkit_network_proxy_settings_new(proxy_uri, NULL);

                webkit_web_context_set_network_proxy_settings(ctx,
                        WEBKIT_NETWORK_PROXY_MODE_CUSTOM, proxy_settings);
                webkit_network_proxy_settings_free(proxy_settings);
            }
            }; break;
        case L_TK_ACCEPT_POLICY:
            luaH_soup_set_accept_policy(L);
            break;
        default:
            break;
    }
    return 0;
}
#endif

void
soup_lib_setup(lua_State *L)
{
    static const struct luaL_reg soup_lib[] =
    {
        LUA_CLASS_METHODS(soup)
#if WEBKIT_CHECK_VERSION(2,16,0)
        { "__index",       luaH_soup_index },
        { "__newindex",    luaH_soup_newindex },
#endif
        { "parse_uri",     luaH_soup_parse_uri },
        { "uri_tostring",  luaH_soup_uri_tostring },
        { NULL,            NULL },
    };

    /* create signals array */
    soup_class.signals = signal_new();

    /* export soup lib */
    luaH_openlib(L, "soup", soup_lib, soup_lib);

    /* Initial proxy settings */
    proxy_uri = g_strdup("default");

    scheme_reg = g_regex_new("^[a-z][a-z0-9\\+\\-\\.]*:", G_REGEX_OPTIMIZE, 0, NULL);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
