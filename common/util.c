/*
 * common/util.c - useful functions
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

#include <glib/gprintf.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>

gboolean
file_exists(const gchar *filename)
{
    return (access(filename, F_OK) == 0);
}

/* Pretty-format calling function filename, function name & line number for
 * debugging purposes */
gchar*
luaH_callerinfo(lua_State *L)
{
    lua_Debug ar;

    /* get information about calling lua function */
    if (lua_getstack(L, 1, &ar) && lua_getinfo(L, "Sln", &ar))
        return g_strdup_printf("%s%s%s:%d", ar.short_src,
            ar.name ? ":" : "", ar.name ? ar.name : "", ar.currentline);

    return NULL;
}

gint
luaH_panic(lua_State *L)
{
    error("unprotected error in call to Lua API (%s)", lua_tostring(L, -1));
    return 0;
}

gchar *
strip_ansi_escapes(const gchar *in)
{
    static GRegex *reg;

    if (!reg) {
        const gchar *expr = "[\\u001b\\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]";
        GError *err = NULL;
        reg = g_regex_new(expr, G_REGEX_JAVASCRIPT_COMPAT | G_REGEX_DOTALL | G_REGEX_EXTENDED | G_REGEX_RAW | G_REGEX_OPTIMIZE, 0, &err);
        g_assert_no_error(err);
    }

    return g_regex_replace_literal (reg, in, -1, 0, "", 0, NULL);
}

GQuark
luakit_error_quark(void)
{
    return g_quark_from_static_string("LuakitError");
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
