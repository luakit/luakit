/*
 * clib/soup/soup.h - soup library
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

#ifndef LUAKIT_CLIB_SOUP_H
#define LUAKIT_CLIB_SOUP_H

#include "clib/soup/cookiejar.h"
#include "clib/soup/auth.h"
#include "luah.h"

#include <libsoup/soup-session.h>
#include <libsoup/soup-uri.h>

typedef struct {
    /* shared libsoup session */
    SoupSession *session;
    /* shared custom cookie jar */
    LuakitCookieJar *cookiejar;
    /* soup signals table */
    signal_t *signals;
} soup_t;

soup_t soupconf;

void soup_lib_setup(lua_State *L);
gint luaH_soup_push_uri(lua_State *L, SoupURI *uri);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
