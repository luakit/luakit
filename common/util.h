/*
 * common/util.h - useful functions
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
#include <lua.h>
#include <sys/time.h>

#include "common/log.h"

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

#define WARN_UNUSED __attribute__ ((warn_unused_result))

/* stack pushing macros */
#define PB_CASE(t, b) case L_TK_##t: lua_pushboolean       (L, b); return 1;
#define PF_CASE(t, f) case L_TK_##t: lua_pushcfunction     (L, f); return 1;
#define PI_CASE(t, i) case L_TK_##t: lua_pushinteger       (L, i); return 1;
#define PN_CASE(t, n) case L_TK_##t: lua_pushnumber        (L, n); return 1;
#define PS_CASE(t, s) case L_TK_##t: lua_pushstring        (L, s); return 1;
#define PD_CASE(t, d) case L_TK_##t: lua_pushlightuserdata (L, d); return 1;

/* A NULL resistant strlen. Unlike it's libc sibling, l_strlen returns a
 * ssize_t, and supports its argument being NULL. */
static inline ssize_t l_strlen(const gchar *s) {
    return s ? strlen(s) : 0;
}

static inline gdouble l_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + (tv.tv_usec / 1e6);
}

#define p_clear(p, count)       ((void)memset((p), 0, sizeof(*(p)) * (count)))

gboolean file_exists(const gchar*);
void l_exec(const gchar*);
gchar *luaH_callerinfo(lua_State*);
gint luaH_panic(lua_State *L);
gchar *strip_ansi_escapes(const gchar *in);

/* Error codes */

GQuark luakit_error_quark(void);

#define LUAKIT_ERROR luakit_error_quark()

enum LuakitError {
    LUAKIT_ERROR_TLS,
};

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
