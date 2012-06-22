/*
 * clib/soup/cookiejar.c - LuakitCookieJar
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#include "clib/soup/soup.h"
#include "luah.h"

#include <libsoup/soup-cookie.h>
#include <libsoup/soup-date.h>
#include <libsoup/soup-message.h>
#include <libsoup/soup-session-feature.h>
#include <libsoup/soup-uri.h>

static void luakit_cookie_jar_session_feature_init(SoupSessionFeatureInterface *interface, gpointer data);
G_DEFINE_TYPE_WITH_CODE (LuakitCookieJar, luakit_cookie_jar, SOUP_TYPE_COOKIE_JAR,
        G_IMPLEMENT_INTERFACE (SOUP_TYPE_SESSION_FEATURE, luakit_cookie_jar_session_feature_init))

inline LuakitCookieJar*
luakit_cookie_jar_new(void)
{
    return g_object_new(LUAKIT_TYPE_COOKIE_JAR, NULL);
}

static gint
luaH_cookie_push(lua_State *L, SoupCookie *c)
{
    lua_createtable(L, 0, 7);

#define PUSH_PROP(prop, type)   \
    lua_pushliteral(L, #prop);  \
    lua_push##type(L, c->prop); \
    lua_rawset(L, -3);

    PUSH_PROP(name,      string)
    PUSH_PROP(value,     string)
    PUSH_PROP(domain,    string)
    PUSH_PROP(path,      string)
    PUSH_PROP(secure,    boolean)
    PUSH_PROP(http_only, boolean)

#undef PUSH_PROP

    /* push expires */
    lua_pushliteral(L, "expires");
    if (c->expires)
        lua_pushnumber(L, soup_date_to_time_t(c->expires));
    else
        lua_pushnumber(L, -1);
    lua_rawset(L, -3);

    return 1;
}

static SoupCookie*
luaH_cookie_from_table(lua_State *L, gint idx, gchar **error)
{
    g_assert(error != NULL);

    SoupDate *date;
    SoupCookie *cookie = NULL;
    const gchar *name = NULL, *value = NULL, *domain = NULL, *path = NULL;
    gboolean secure = FALSE, http_only = FALSE;
    gint top = lua_gettop(L), expires = 0, type;

    /* correct relative index */
    if (idx < 0)
        idx = top + idx + 1;

    /* cookie.domain */
    if (luaH_rawfield(L, idx, "domain") == LUA_TSTRING)
        domain = lua_tostring(L, -1);

    /* cookie.name */
    if (luaH_rawfield(L, idx, "path") == LUA_TSTRING)
        path = lua_tostring(L, -1);

    /* cookie.name */
    if ((type = luaH_rawfield(L, idx, "name")) == LUA_TSTRING)
        name = lua_tostring(L, -1);
    else if (type == LUA_TNIL)
        name = "";

    /* cookie.expires */
    if (luaH_rawfield(L, idx, "expires") == LUA_TNUMBER)
        expires = lua_tointeger(L, -1);

    /* cookie.value */
    if ((type = luaH_rawfield(L, idx, "value")) == LUA_TSTRING)
        value = lua_tostring(L, -1);
    else if (type == LUA_TNIL) { /* expire cookie if value = nil */
        value = "";
        expires = 0;
    }

    /* cookie.http_only */
    if ((type = luaH_rawfield(L, idx, "http_only")) == LUA_TNUMBER)
        http_only = lua_tointeger(L, -1) ? TRUE : FALSE;
    else if (type == LUA_TBOOLEAN)
        http_only = lua_toboolean(L, -1);

    /* cookie.secure */
    if ((type = luaH_rawfield(L, idx, "secure")) == LUA_TNUMBER)
        secure = lua_tointeger(L, -1) ? TRUE : FALSE;
    else if (type == LUA_TBOOLEAN)
        secure = lua_toboolean(L, -1);

    /* truncate luaH_rawfield leftovers */
    lua_settop(L, top);

    /* create soup cookie */
    if (domain && domain[0] && path && path[0] && name && value)
        cookie = soup_cookie_new(name, value, domain, path, 0);

    if (!cookie) {
        *error = g_strdup_printf("soup_cookie_new call failed ("
                "domain '%s', path '%s', name '%s', value '%s', "
                "secure %d, http_only %d)", domain, path, name,
                value, secure, http_only);
        return NULL;
    }

    soup_cookie_set_secure(cookie, secure);
    soup_cookie_set_http_only(cookie, http_only);

    /* set expiry date from unixtime */
    if (expires > 0) {
        date = soup_date_new_from_time_t((time_t) expires);
        soup_cookie_set_expires(cookie, date);
        soup_date_free(date);

    /* set session cookie */
    } else if (expires == -1)
        soup_cookie_set_max_age(cookie, expires);

    return cookie;
}

static GSList*
cookies_from_table(lua_State *L, gint idx)
{
    GSList *cookies = NULL;
    SoupCookie *cookie;

    /* iterate over cookies table */
    lua_pushnil(L);
    while (lua_next(L, idx)) {
        /* error if not table */
        if (!lua_istable(L, -1)) {
            g_slist_free_full(cookies, (GDestroyNotify)soup_cookie_free);
            luaL_error(L, "invalid cookie (table expected, got %s)",
                    lua_typename(L, lua_type(L, -1)));
        }

        gchar *error;
        /* create soup cookie from table */
        if ((cookie = luaH_cookie_from_table(L, -1, &error))) {
            cookies = g_slist_prepend(cookies, cookie);

        /* bad cookie, raise error */
        } else if (error) {
            g_slist_free_full(cookies, (GDestroyNotify)soup_cookie_free);
            lua_pushstring(L, error);
            g_free(error);
            lua_error(L);
        }

        lua_pop(L, 1); /* pop cookie */
    }
    return cookies;
}

gint
luaH_cookiejar_add_cookies(lua_State *L)
{
    SoupCookieJar *sj = SOUP_COOKIE_JAR(soupconf.cookiejar);
    LuakitCookieJar *j = LUAKIT_COOKIE_JAR(soupconf.cookiejar);
    GSList *cookies;
    gboolean silent = TRUE;

    /* cookies table */
    luaH_checktable(L, 1);

    /* optional silent parameter */
    if (lua_gettop(L) >= 2)
        silent = luaH_checkboolean(L, 2);

    /* get cookies from table */
    if ((cookies = cookies_from_table(L, 1))) {
        j->silent = silent;

        /* insert cookies */
        for (GSList *p = cookies; p; p = g_slist_next(p))
            soup_cookie_jar_add_cookie(sj, p->data);

        g_slist_free(cookies);
        j->silent = FALSE;
    }

    return 0;
}

static void
request_started(SoupSessionFeature *feature, SoupSession* UNUSED(session),
        SoupMessage *msg, SoupSocket* UNUSED(socket))
{
    SoupCookieJar *sj = SOUP_COOKIE_JAR(feature);
    SoupURI *uri = soup_message_get_uri(msg);
    lua_State *L = globalconf.L;

    /* give user a chance to add cookies from other instances into the jar */
    gchar *str = soup_uri_to_string(uri, FALSE);
    lua_pushstring(L, str);
    g_free(str);
    signal_object_emit(L, soup_class.signals, "request-started", 1, 0);

    /* generate cookie header */
    gchar *header = soup_cookie_jar_get_cookies(sj, uri, TRUE);
    if (header) {
        soup_message_headers_replace(msg->request_headers, "Cookie", header);
        g_free(header);
    } else
        soup_message_headers_remove(msg->request_headers, "Cookie");
}

/* soup_cookie_equal wasn't good enough */
inline static gboolean
soup_cookie_truly_equal(SoupCookie *c1, SoupCookie *c2)
{
    return (!g_strcmp0(c1->name, c2->name) &&
        !g_strcmp0(c1->value, c2->value)   &&
        !g_strcmp0(c1->path,  c2->path)    &&
        (c1->secure    == c2->secure)      &&
        (c1->http_only == c2->http_only)   &&
        (c1->expires && c2->expires        &&
        (soup_date_to_time_t(c1->expires) ==
         soup_date_to_time_t(c2->expires))));
}

static void
changed(SoupCookieJar *sj, SoupCookie *old, SoupCookie *new)
{
    if (LUAKIT_COOKIE_JAR(sj)->silent)
        return;

    lua_State *L = globalconf.L;

    /* do nothing if cookies are equal */
    if (old && new && soup_cookie_truly_equal(old, new))
        return;

    if (old)
        luaH_cookie_push(L, old);
    else
        lua_pushnil(L);

    if (new)
        luaH_cookie_push(L, new);
    else
        lua_pushnil(L);

    signal_object_emit(L, soup_class.signals, "cookie-changed", 2, 0);
}

static void
finalize(GObject *object)
{
    G_OBJECT_CLASS(luakit_cookie_jar_parent_class)->finalize(object);
}

static void
luakit_cookie_jar_init(LuakitCookieJar *j)
{
    j->silent = FALSE;
}

static void
luakit_cookie_jar_class_init(LuakitCookieJarClass *class)
{
    G_OBJECT_CLASS(class)->finalize       = finalize;
    SOUP_COOKIE_JAR_CLASS(class)->changed = changed;
}

static void
luakit_cookie_jar_session_feature_init(SoupSessionFeatureInterface *interface,
        gpointer UNUSED(data))
{
    interface->request_started = request_started;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
