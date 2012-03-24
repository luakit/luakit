/*
 * util.h - useful functions
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2007-2008 Julien Danjou <julien@danjou.info>
 * Copyright © 2006 Pierre Habouzit <madcoder@debian.org>
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

#ifndef LUAKIT_COMMON_UTIL_H
#define LUAKIT_COMMON_UTIL_H

#include <glib.h>
#include <string.h>
#include <unistd.h>

/* Useful macros */
#define NONULL(x) (x ? x : "")
#define LENGTH(x) sizeof(x)/sizeof((x)[0])

#ifdef UNUSED
#elif defined(__GNUC__)
# define UNUSED(x) UNUSED_ ## x __attribute__((unused))
#elif defined(__LCLINT__)
# define UNUSED(x) /*@unused@*/ x
#else
# define UNUSED(x) x
#endif

/* stack pushing macros */
#define PB_CASE(t, b) case L_TK_##t: lua_pushboolean   (L, b); return 1;
#define PF_CASE(t, f) case L_TK_##t: lua_pushcfunction (L, f); return 1;
#define PI_CASE(t, i) case L_TK_##t: lua_pushinteger   (L, i); return 1;
#define PN_CASE(t, n) case L_TK_##t: lua_pushnumber    (L, n); return 1;
#define PS_CASE(t, s) case L_TK_##t: lua_pushstring    (L, s); return 1;

#define fatal(string, ...) _fatal(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _fatal(int, const gchar *, const gchar *, ...);

#define warn(string, ...) _warn(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _warn(int, const gchar *, const gchar *, ...);

#define debug(string, ...) _debug(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _debug(int, const gchar *, const gchar *, ...);

/* A NULL resistant strlen. Unlike it's libc sibling, l_strlen returns a
 * ssize_t, and supports its argument being NULL. */
static inline ssize_t l_strlen(const gchar *s) {
    return s ? strlen(s) : 0;
}

#define p_clear(p, count)       ((void)memset((p), 0, sizeof(*(p)) * (count)))

gboolean file_exists(const gchar*);
void l_exec(const gchar*);

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
