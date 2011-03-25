/*
 * classes/soup/soup.c - soup library
 *
 * Copyright (C) 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "classes/soup/soup.h"
#include "common/property.h"

#include <libsoup/soup.h>
#include <webkit/webkitsoupauthdialog.h>
#include <webkit/webkitwebview.h>

GHashTable *soup_properties = NULL;
property_t soup_properties_table[] = {
  { "accept-language",      CHAR,   SESSION,   TRUE,  NULL },
  { "accept-language-auto", BOOL,   SESSION,   TRUE,  NULL },
  { "accept-policy",        INT,    COOKIEJAR, TRUE,  NULL },
  { "idle-timeout",         INT,    SESSION,   TRUE,  NULL },
  { "max-conns",            INT,    SESSION,   TRUE,  NULL },
  { "max-conns-per-host",   INT,    SESSION,   TRUE,  NULL },
  { "proxy-uri",            URI,    SESSION,   TRUE,  NULL },
  { "ssl-ca-file",          CHAR,   SESSION,   TRUE,  NULL },
  { "ssl-strict",           BOOL,   SESSION,   TRUE,  NULL },
  { "timeout",              INT,    SESSION,   TRUE,  NULL },
  { "use-ntlm",             BOOL,   SESSION,   TRUE,  NULL },
  { NULL,                   0,      0,         0,     NULL },
};

inline static gint
luaH_soup_get_property(lua_State *L)
{
    return luaH_get_property(L, soup_properties, NULL, 1);
}

inline static gint
luaH_soup_set_property(lua_State *L)
{
    return luaH_set_property(L, soup_properties, NULL, 1, 2);
}

/* Add a soup signal.
 * Returns the number of elements pushed on stack.
 * \luastack
 * \lparam A string with the event name.
 * \lparam The function to call.
 */
static gint
luaH_soup_add_signal(lua_State *L)
{
    const gchar *name = luaL_checkstring(L, 1);
    luaH_checkfunction(L, 2);
    signal_add(soupconf.signals, name, luaH_object_ref(L, 2));
    return 0;
}

/* Remove a soup signal.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 * \luastack
 * \lparam A string with the event name.
 * \lparam The function to call.
 */
static gint
luaH_soup_remove_signal(lua_State *L)
{
    const gchar *name = luaL_checkstring(L, 1);
    luaH_checkfunction(L, 2);
    gpointer func = (gpointer) lua_topointer(L, 2);
    signal_remove(soupconf.signals, name, func);
    luaH_object_unref(L, (gpointer) func);
    return 0;
}

/* Emit a global signal.
 * \param L The Lua VM state.
 * \return The number of elements pushed on stack.
 * \luastack
 * \lparam A string with the event name.
 * \lparam The function to call.
 */
static gint
luaH_soup_emit_signal(lua_State *L)
{
    return signal_object_emit(L, soupconf.signals, luaL_checkstring(L, 1),
            lua_gettop(L) - 1, LUA_MULTRET);
}

static void
soup_notify_cb(SoupSession *s, GParamSpec *ps, gpointer *d)
{
    (void) s;
    (void) d;
    property_t *p;
    /* emit soup property signal if found in properties table */
    if ((p = g_hash_table_lookup(soup_properties, ps->name))) {
        lua_State *L = globalconf.L;
        signal_object_emit(L, soupconf.signals, p->signame, 0, 0);
    }
}

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

#undef GET_PROP

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

#undef PUSH_PROP

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

void
soup_lib_setup(lua_State *L)
{
    static const struct luaL_reg soup_lib[] = {
        { "add_signal",    luaH_soup_add_signal },
        { "remove_signal", luaH_soup_remove_signal },
        { "emit_signal",   luaH_soup_emit_signal },
        { "set_property",  luaH_soup_set_property },
        { "get_property",  luaH_soup_get_property },
        { "parse_uri",     luaH_soup_parse_uri },
        { "uri_tostring",  luaH_soup_uri_tostring },
        { "add_cookies",   luaH_cookiejar_add_cookies },
        { NULL,            NULL },
    };

    /* hash soup properties table */
    soup_properties = hash_properties(soup_properties_table);

    /* init soup struct */
    soupconf.cookiejar = luakit_cookie_jar_new();
    soupconf.session = webkit_get_default_session();
    soup_session_add_feature(soupconf.session,
            (SoupSessionFeature*) soupconf.cookiejar);
    soupconf.signals = signal_new();

    /* watch for property changes */
    g_signal_connect(G_OBJECT(soupconf.session), "notify",
            G_CALLBACK(soup_notify_cb), NULL);

    /* remove old auth dialog and add luakit's auth feature instead */
    soup_session_remove_feature_by_type(soupconf.session,
            WEBKIT_TYPE_SOUP_AUTH_DIALOG);
    soup_session_add_feature(soupconf.session,
            (SoupSessionFeature*) luakit_auth_dialog_new());

    /* export soup lib */
    luaH_openlib(L, "soup", soup_lib, soup_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
