/*
 * util.c - useful functions
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

#include "common/util.h"
#include "globalconf.h"

#include <glib/gprintf.h>
#include <stdarg.h>
#include <stdlib.h>

/* Print error and exit with EXIT_FAILURE code. */
void
_fatal(gint line, const gchar *fct, const gchar *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    g_fprintf(stderr, "E: luakit: %s:%d: ", fct, line);
    g_vfprintf(stderr, fmt, ap);
    va_end(ap);
    g_fprintf(stderr, "\n");
    exit(EXIT_FAILURE);
}

/* Print error message on stderr. */
void
_warn(gint line, const gchar *fct, const gchar *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    g_fprintf(stderr, "W: luakit: %s:%d: ", fct, line);
    g_vfprintf(stderr, fmt, ap);
    va_end(ap);
    g_fprintf(stderr, "\n");
}

/* Print debug message on stderr. */
void
_debug(gint line, const gchar *fct, const gchar *fmt, ...) {
    if (globalconf.verbose) {
        va_list ap;
        va_start(ap, fmt);
        g_fprintf(stderr, "D: luakit: %s:%d: ", fct, line);
        g_vfprintf(stderr, fmt, ap);
        va_end(ap);
        g_fprintf(stderr, "\n");
    }
}

gboolean
file_exists(const gchar *filename)
{
    return (access(filename, F_OK) == 0);
}

/* Execute a command and replace the current process. */
void
l_exec(const gchar *cmd)
{
    static const gchar *shell = NULL;

    if(!shell && !(shell = g_getenv("SHELL")))
        shell = "/bin/sh";

    execl(shell, shell, "-c", cmd, NULL);
}
