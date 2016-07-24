/*
 * common/log.c - logging functions
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

#include "globalconf.h"
#include "common/log.h"
#include "common/luaserialize.h"

#include <glib/gprintf.h>
#include <stdlib.h>
#include <unistd.h>

static log_level_t verbosity;

void
log_set_verbosity(log_level_t lvl)
{
    verbosity = lvl;
}

log_level_t
log_get_verbosity(void)
{
    return verbosity;
}

int
log_level_from_string(log_level_t *out, const char *str)
{
#define X(name) if (!strcmp(#name, str)) { \
    *out = LOG_LEVEL_##name; \
    return 0; \
}
LOG_LEVELS
#undef X
    return 1;
}

void
_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    va_log(lvl, line, fct, fmt, ap);
    va_end(ap);
}

void
va_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, va_list ap)
{
    if (lvl > verbosity)
        return;

    gchar prefix_char;
    switch (lvl) {
        case LOG_LEVEL_fatal:   prefix_char = 'E'; break;
        case LOG_LEVEL_warn:    prefix_char = 'W'; break;
        case LOG_LEVEL_info:    prefix_char = 'I'; break;
        case LOG_LEVEL_verbose: prefix_char = 'V'; break;
        case LOG_LEVEL_debug:   prefix_char = 'D'; break;
    }

    gint atty = isatty(STDERR_FILENO);
    if (atty && lvl == LOG_LEVEL_fatal) g_fprintf(stderr, ANSI_COLOR_BG_RED);
    if (atty && lvl == LOG_LEVEL_warn) g_fprintf(stderr, ANSI_COLOR_RED);
    g_fprintf(stderr, "[%#12f] ", l_time() - globalconf.starttime);
    g_fprintf(stderr, "%c: %s:%d: ", prefix_char, fct, line);
    g_vfprintf(stderr, fmt, ap);
    if (atty) g_fprintf(stderr, ANSI_COLOR_RESET);
    g_fprintf(stderr, "\n");

    if (lvl == LOG_LEVEL_fatal)
        exit(EXIT_FAILURE);
}

void
msg_recv_log(const guint8 *lua_msg, guint length)
{
    lua_State *L = globalconf.L;
    gint n = lua_deserialize_range(L, lua_msg, length);
    g_assert_cmpint(n, ==, 4);

    log_level_t lvl = lua_tointeger(L, -4);
    gint line = lua_tointeger(L, -3);
    const gchar *fct = lua_tostring(L, -2);
    const gchar *msg = lua_tostring(L, -1);
    _log(lvl, line, fct, "%s", msg);
    lua_pop(L, 4);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
