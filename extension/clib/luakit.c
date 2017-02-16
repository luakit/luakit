/*
 * extension/clib/luakit.c - Generic functions for Lua scripts
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

#include "extension/clib/luakit.h"
#include "common/clib/luakit.h"
#include "common/signal.h"

#include <glib.h>
#include <gtk/gtk.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <webkit2/webkit2.h>

/* lua luakit class for signals */
lua_class_t luakit_class;

/* setup luakit module signals */
LUA_CLASS_FUNCS(luakit, luakit_class)

/** Setup luakit module.
 *
 * \param L The Lua VM state.
 */
void
luakit_lib_setup(lua_State *L)
{
    static const struct luaL_reg luakit_lib[] =
    {
        LUA_CLASS_METHODS(luakit)
        LUAKIT_LIB_COMMON_METHODS
        { NULL,              NULL }
    };

    /* create signals array */
    luakit_class.signals = signal_new();

    /* export luakit lib */
    luaH_openlib(L, "luakit", luakit_lib, luakit_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
