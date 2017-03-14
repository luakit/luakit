/*
 * log.c - logging functions
 *
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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
#include "common/ipc.h"

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

    gchar *msg = g_strdup_vprintf(fmt, ap);
    gint log_fd = STDERR_FILENO;

    /* Determine logging style */
    /* TODO: move to X-macro generated table? */

    gchar prefix_char, *style = "";
    switch (lvl) {
        case LOG_LEVEL_fatal:   prefix_char = 'E'; style = ANSI_COLOR_BG_RED; break;
        case LOG_LEVEL_warn:    prefix_char = 'W'; style = ANSI_COLOR_RED; break;
        case LOG_LEVEL_info:    prefix_char = 'I'; break;
        case LOG_LEVEL_verbose: prefix_char = 'V'; break;
        case LOG_LEVEL_debug:   prefix_char = 'D'; break;
    }

    /* Log format: [timestamp] prefix: fct:line msg */
#define LOG_FMT "[%#12f] %c: %s:%d: %s"

    if (!isatty(log_fd)) {
        static GRegex *reg;

        if (!reg) {
            const gchar *expr = "[\\u001b\\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]";
            GError *err = NULL;
            reg = g_regex_new(expr, G_REGEX_JAVASCRIPT_COMPAT | G_REGEX_DOTALL | G_REGEX_EXTENDED | G_REGEX_RAW | G_REGEX_OPTIMIZE, 0, &err);
            g_assert_no_error(err);
        }

        gchar *stripped = g_regex_replace_literal (reg, msg, -1, 0, "", 0, NULL);
        g_free(msg);
        msg = stripped;

        g_fprintf(stderr, LOG_FMT "\n",
                l_time() - globalconf.starttime,
                prefix_char, fct, line, msg);
    } else {
        g_fprintf(stderr, "%s" LOG_FMT ANSI_COLOR_RESET "\n",
                style,
                l_time() - globalconf.starttime,
                prefix_char, fct, line, msg);
    }

    g_free(msg);

    if (lvl == LOG_LEVEL_fatal)
        exit(EXIT_FAILURE);
}

void
ipc_recv_log(ipc_endpoint_t *UNUSED(ipc), const guint8 *lua_msg, guint length)
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
