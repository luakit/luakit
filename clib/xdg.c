/*
 * clib/xdg.c - XDG Base Directory Specification paths
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

#include "clib/xdg.h"
#include "luah.h"

static gint
luaH_xdg_index(lua_State *L)
{
    if (!lua_isstring(L, 2)) /* ignore non-string indexes */
        return 0;

    switch(l_tokenize(lua_tostring(L, 2)))
    {
      PS_CASE(CACHE_DIR,  g_get_user_cache_dir())
      PS_CASE(CONFIG_DIR, g_get_user_config_dir())
      PS_CASE(DATA_DIR,   g_get_user_data_dir())

#define UD_CASE(TOK)                                                       \
      case L_TK_##TOK##_DIR:                                               \
        lua_pushstring(L, g_get_user_special_dir(G_USER_DIRECTORY_##TOK)); \
        return 1;

      UD_CASE(DESKTOP)
      UD_CASE(DOCUMENTS)
      UD_CASE(DOWNLOAD)
      UD_CASE(MUSIC)
      UD_CASE(PICTURES)
      UD_CASE(PUBLIC_SHARE)
      UD_CASE(TEMPLATES)
      UD_CASE(VIDEOS)

      default:
        break;
    }
    return 0;
}

void
xdg_lib_setup(lua_State *L)
{
    static const struct luaL_reg xdg_lib[] =
    {
        { "__index", luaH_xdg_index },
        { NULL, NULL },
    };

    luaH_openlib(L, "xdg", xdg_lib, xdg_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
