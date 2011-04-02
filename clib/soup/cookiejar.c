/*
 * classes/soup/cookiejar.c - LuakitCookieJar
 *
 * Copyright (C) 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "classes/soup/soup.h"
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
cookie_new_from_table(lua_State *L, gint idx, gchar **error)
{
    SoupCookie *cookie = NULL;
    SoupDate *date;
    const gchar *name, *value, *domain, *path;
    name = value = domain = path = NULL;
    gboolean secure, http_only;
    gint expires;

    /* correct relative index */
    if (idx < 0)
        idx = lua_gettop(L) + idx + 1;

    /* check for cookie table */
    if (!lua_istable(L, idx)) {
        *error = g_strdup_printf("invalid cookie table, got %s",
            lua_typename(L, lua_type(L, idx)));
        return NULL;
    }

#define IS_STRING  (lua_isstring(L, -1)  || lua_isnumber(L, -1))
#define IS_BOOLEAN (lua_isboolean(L, -1) || lua_isnil(L, -1))
#define IS_NUMBER  (lua_isnumber(L, -1))

#define GET_PROP(prop, typname, typexpr, typfunc)                           \
    lua_pushliteral(L, #prop);                                              \
    lua_rawget(L, idx);                                                     \
    if ((typexpr)) {                                                        \
        prop = typfunc(L, -1);                                              \
        lua_pop(L, 1);                                                      \
    } else {                                                                \
        *error = g_strdup_printf("invalid cookie." #prop " type, expected " \
            #typname ", got %s",  lua_typename(L, lua_type(L, -1)));        \
        return NULL;                                                        \
    }

    /* get cookie properties */
    GET_PROP(name,      string,  IS_STRING,  lua_tostring)
    GET_PROP(value,     string,  IS_STRING,  lua_tostring)
    GET_PROP(domain,    string,  IS_STRING,  lua_tostring)
    GET_PROP(path,      string,  IS_STRING,  lua_tostring)
    GET_PROP(secure,    boolean, IS_BOOLEAN, lua_toboolean)
    GET_PROP(http_only, boolean, IS_BOOLEAN, lua_toboolean)
    GET_PROP(expires,   number,  IS_NUMBER,  lua_tonumber)

#undef IS_STRING
#undef IS_BOOLEAN
#undef IS_NUMBER
#undef GET_PROP

    /* create soup cookie */
    if ((cookie = soup_cookie_new(name, value, domain, path, expires))) {
        soup_cookie_set_secure(cookie, secure);
        soup_cookie_set_http_only(cookie, http_only);

        /* set real expiry date from unixtime */
        if (expires > 0) {
            date = soup_date_new_from_time_t((time_t) expires);
            soup_cookie_set_expires(cookie, date);
            soup_date_free(date);
        }

        return cookie;
    }

    /* soup cookie creation failed */
    *error = g_strdup_printf("soup cookie creation failed");
    return NULL;
}

static GSList*
cookies_from_table(lua_State *L, gint idx)
{
    GSList *cookies = NULL;
    SoupCookie *cookie;
    gchar *error;

    /* bring a copy of the table to the top of the stack */
    lua_pushvalue(L, idx);

    /* push first index */
    lua_pushnil(L);

    /* iterate over cookies table */
    while(luaH_next(L, -2)) {
        /* create soup cookie from table */
        if ((cookie = cookie_new_from_table(L, -1, &error)))
            cookies = g_slist_prepend(cookies, cookie);

        /* bad cookie, raise error */
        else if (error) {
            /* free cookies */
            for (GSList *p = cookies; p; p = g_slist_next(p))
                soup_cookie_free(p->data);
            g_slist_free(cookies);

            /* push & raise error */
            lua_pushfstring(L, "bad cookie in cookies table (%s)", error);
            g_free(error);
            lua_error(L);
        }

        /* remove cookie table */
        lua_pop(L, 1);
    }

    /* remove copy of the table */
    lua_pop(L, 1);

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
            soup_cookie_jar_add_cookie(sj, soup_cookie_copy(p->data));

        g_slist_free(cookies);
        j->silent = FALSE;
    }

    return 0;
}

static void
request_started(SoupSessionFeature *feature, SoupSession *session,
        SoupMessage *msg, SoupSocket *socket)
{
    (void) session;
    (void) socket;
    SoupCookieJar *sj = SOUP_COOKIE_JAR(feature);
    SoupURI *uri = soup_message_get_uri(msg);
    lua_State *L = globalconf.L;

    /* give user a chance to add cookies from other instances into the jar */
    gchar *str = soup_uri_to_string(uri, FALSE);
    lua_pushstring(L, str);
    g_free(str);
    signal_object_emit(L, soupconf.signals, "request-started", 1, 0);

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

    signal_object_emit(L, soupconf.signals, "cookie-changed", 2, 0);
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
        gpointer data)
{
    (void) data;
    interface->request_started = request_started;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
