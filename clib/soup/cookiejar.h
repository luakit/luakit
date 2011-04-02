/*
 * clib/soup/cookiejar.h - LuakitCookieJar header
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

#ifndef LUAKIT_CLIB_SOUP_COOKIEJAR_H
#define LUAKIT_CLIB_SOUP_COOKIEJAR_H

#include "luah.h"

#include <libsoup/soup-cookie-jar.h>

#define LUAKIT_TYPE_COOKIE_JAR         (luakit_cookie_jar_get_type ())
#define LUAKIT_COOKIE_JAR(obj)         (G_TYPE_CHECK_INSTANCE_CAST ((obj),   LUAKIT_TYPE_COOKIE_JAR, LuakitCookieJar))
#define LUAKIT_COOKIE_JAR_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST    ((klass), LUAKIT_TYPE_COOKIE_JAR, LuakitCookieJarClass))

typedef struct {
    SoupCookieJar parent;
    gboolean silent;
} LuakitCookieJar;

typedef struct {
    SoupCookieJarClass parent_class;
} LuakitCookieJarClass;

LuakitCookieJar *luakit_cookie_jar_new(void);

gint luaH_cookiejar_add_cookies(lua_State *L);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
