/*
 * common/log.h - logging functions
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

/* ANSI term color codes */
#define ANSI_COLOR_RESET   "\x1b[0m"

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"

#define ANSI_COLOR_BG_RED  "\x1b[41m"

#define fatal(string, ...) _fatal(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _fatal(int, const gchar *, const gchar *, ...);
void va_fatal(int, const gchar *, const gchar *, va_list);

#define warn(string, ...) _warn(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _warn(int, const gchar *, const gchar *, ...);
void va_warn(int, const gchar *, const gchar *, va_list);

#define debug(string, ...) _debug(__LINE__, __FUNCTION__, string, ##__VA_ARGS__)
void _debug(int, const gchar *, const gchar *, ...);
void va_debug(int, const gchar *, const gchar *, va_list);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
