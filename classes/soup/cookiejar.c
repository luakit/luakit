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

#include "classes/soup/cookiejar.h"

/* setup luakit cookie jar type */
G_DEFINE_TYPE (LuakitCookieJar, soup_cookie_jar_luakit, SOUP_TYPE_COOKIE_JAR)

inline LuakitCookieJar*
luakit_cookie_jar_new(void)
{
    return g_object_new(LUAKIT_TYPE_COOKIE_JAR, NULL);
}

static void
soup_cookie_jar_luakit_init(LuakitCookieJar *jar)
{
    (void) jar;
}

static void
finalize_cb(GObject *object)
{
    G_OBJECT_CLASS(soup_cookie_jar_luakit_parent_class)->finalize(object);
}

static void
changed_cb(SoupCookieJar *j, SoupCookie *old, SoupCookie *new)
{
    SoupCookie *c = new ? new : old;

    LuakitCookieJar *jar = LUAKIT_COOKIE_JAR(j);
    (void) jar;

    gchar *expires = NULL;
    if (c->expires)
        expires = g_strdup_printf("%ld", soup_date_to_time_t(c->expires));

    const gchar *scheme = c->secure ? "https" : "http";

    g_printf("Cookie(Domain: '%s', Path: '%s', Name: '%s', Value: '%s', Scheme: %s, Expires: %s)\n",
        c->domain, c->path, c->name, c->value, scheme, expires?expires:"At close");

    if(expires)
        g_free(expires);
}

static void
soup_cookie_jar_luakit_class_init(LuakitCookieJarClass *class)
{
    G_OBJECT_CLASS(class)->finalize       = finalize_cb;
    SOUP_COOKIE_JAR_CLASS(class)->changed = changed_cb;
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
