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

#include <glib/gprintf.h>
#include <stdlib.h>
#include <unistd.h>

void
_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    va_log(lvl, line, fct, fmt, ap);
    va_end(ap);
}

void
va_log(log_level_t lvl, gint line, const gchar *fct, const gchar *fmt, va_list ap) {
    if (lvl <= LOG_LEVEL_debug && !globalconf.verbose)
        return;

    gchar prefix_char;
    switch (lvl) {
        case LOG_LEVEL_fatal: prefix_char = 'E'; break;
        case LOG_LEVEL_warn:  prefix_char = 'W'; break;
        case LOG_LEVEL_debug: prefix_char = 'D'; break;
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

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
