/*
 * common/log.h - logging functions
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

#ifndef LUAKIT_COMMON_LOG_H
#define LUAKIT_COMMON_LOG_H

#include <glib.h>
#include <stdarg.h>

#define LOG_LEVELS \
    X(fatal) \
    X(error) \
    X(warn) \
    X(info) \
    X(verbose) \
    X(debug) \

#define X(name) LOG_LEVEL_##name,
typedef enum { LOG_LEVELS } log_level_t;
#undef X

/* ANSI term color codes */
#define ANSI_COLOR_RESET   "\x1b[0m"

#define ANSI_COLOR_BLACK   "\x1b[30m"
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_GRAY    "\x1b[37m"

#define ANSI_COLOR_BG_RED  "\x1b[41m"

#define log(lvl, string, ...) _log(lvl, __FILE__, string, ##__VA_ARGS__)
void _log(log_level_t lvl, const gchar *, const gchar *, ...)
    __attribute__ ((format (printf, 3, 4)));
void va_log(log_level_t lvl, const gchar *, const gchar *, va_list);

#define fatal(...) log(LOG_LEVEL_fatal, ##__VA_ARGS__)
#define error(...) log(LOG_LEVEL_error, ##__VA_ARGS__)
#define warn(...) log(LOG_LEVEL_warn, ##__VA_ARGS__)
#define info(...) log(LOG_LEVEL_info, ##__VA_ARGS__)
#define verbose(...) log(LOG_LEVEL_verbose, ##__VA_ARGS__)
#define debug(...) log(LOG_LEVEL_debug, ##__VA_ARGS__)

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
