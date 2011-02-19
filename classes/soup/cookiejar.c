/*
 * classes/soup/cookiejar.c - LuakitSoupCookieJar
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

#include <libsoup/soup-cookie.h>
#include <libsoup/soup-date.h>
#include <libsoup/soup-message.h>
#include <libsoup/soup-session-feature.h>

#include "classes/soup/soup.h"
#include "luah.h"

static void luakit_cookie_jar_session_feature_init(SoupSessionFeatureInterface *interface, gpointer data);
G_DEFINE_TYPE_WITH_CODE (LuakitCookieJar, luakit_cookie_jar, SOUP_TYPE_COOKIE_JAR,
        G_IMPLEMENT_INTERFACE (SOUP_TYPE_SESSION_FEATURE, luakit_cookie_jar_session_feature_init))

inline LuakitCookieJar*
luakit_cookie_jar_new(void)
{
    return g_object_new(LUAKIT_TYPE_COOKIE_JAR, NULL);
}

/* Push all the uri details required from the message SoupURI for the cookie
 * callback to determine the correct cookies to return */
static gint
luaH_push_message_uri(lua_State *L, SoupURI *uri)
{
    lua_createtable(L, 0, 3);
    /* push scheme */
    lua_pushliteral(L, "scheme");
    lua_pushstring(L, uri->scheme);
    lua_rawset(L, -3);
    /* push host */
    lua_pushliteral(L, "host");
    lua_pushstring(L, uri->host);
    lua_rawset(L, -3);
    /* push path */
    lua_pushliteral(L, "path");
    lua_pushstring(L, uri->path);
    lua_rawset(L, -3);
    return 1;
}

static void
request_started(SoupSessionFeature *feature, SoupSession *session, SoupMessage *msg, SoupSocket *socket)
{
    (void) session;
    (void) socket;
    LuakitCookieJar *jar = LUAKIT_COOKIE_JAR(feature);

    /* get pertinent cookies from lua */
    lua_State *L = globalconf.L;
    luaH_push_message_uri(L, soup_message_get_uri(msg));
    //g_printf("Current: %s\n", soup_cookie_jar_get_cookies(SOUP_COOKIE_JAR(jar), soup_message_get_uri(msg), TRUE));
    //gint ret = signal_object_emit(L, soupconf.signals, "request-cookies", 1, 1);
}

static void
changed(SoupCookieJar *jar, SoupCookie *old, SoupCookie *new)
{
    (void) jar;
    lua_State *L = globalconf.L;

    if (old) {
        luaH_cookie_push(L, old);
        signal_object_emit(L, soupconf.signals, "del-cookie", 1, 0);
    }

    if (new) {
        luaH_cookie_push(L, new);
        signal_object_emit(L, soupconf.signals, "add-cookie", 1, 0);
    }
}

static void
finalize(GObject *object)
{
    G_OBJECT_CLASS(luakit_cookie_jar_parent_class)->finalize(object);
}


static void
luakit_cookie_jar_init(LuakitCookieJar *jar)
{
    (void) jar;
}

static void
luakit_cookie_jar_class_init(LuakitCookieJarClass *class)
{
    G_OBJECT_CLASS(class)->finalize       = finalize;
    SOUP_COOKIE_JAR_CLASS(class)->changed = changed;
}

static void
luakit_cookie_jar_session_feature_init(SoupSessionFeatureInterface *interface, gpointer data)
{
    (void) data;
    interface->request_started = request_started;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
