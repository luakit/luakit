/*
 * clib/xdg.c - XDG Base Directory Specification paths
 *
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
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

#include "clib/xdg.h"
#include "luah.h"

static void
str_chomp_slashes(gchar *path)
{
    if (!path)
        return;
    gint last = strlen(path) - 1;
    while (last > 0 && path[last] == '/')
        path[last--] = '\0';
}

static int
luaH_push_path(lua_State *L, const gchar *path)
{
    gchar *p = g_strdup(path);
    str_chomp_slashes(p);
    lua_pushstring(L, p);
    g_free(p);
    return 1;
}

static int
luaH_push_path_array(lua_State *L, const gchar * const * paths)
{
    lua_newtable(L);
    for (gint n = 0; paths[n]; ++n) {
        luaH_push_path(L, paths[n]);
        lua_rawseti(L, -2, n+1);
    }
    return 1;
}

static gint
luaH_xdg_index(lua_State *L)
{
    if (!lua_isstring(L, 2)) /* ignore non-string indexes */
        return 0;

    switch(l_tokenize(lua_tostring(L, 2)))
    {
#define PP_CASE(t, s) case L_TK_##t: luaH_push_path(L, s); return 1;

      PP_CASE(CACHE_DIR,  g_get_user_cache_dir())
      PP_CASE(CONFIG_DIR, g_get_user_config_dir())
      PP_CASE(DATA_DIR,   g_get_user_data_dir())

#define UD_CASE(TOK)                                                       \
      case L_TK_##TOK##_DIR:                                               \
        luaH_push_path(L, g_get_user_special_dir(G_USER_DIRECTORY_##TOK)); \
        return 1;

      UD_CASE(DESKTOP)
      UD_CASE(DOCUMENTS)
      UD_CASE(DOWNLOAD)
      UD_CASE(MUSIC)
      UD_CASE(PICTURES)
      UD_CASE(PUBLIC_SHARE)
      UD_CASE(TEMPLATES)
      UD_CASE(VIDEOS)

      case L_TK_SYSTEM_DATA_DIRS:
        return luaH_push_path_array(L, g_get_system_data_dirs());

      case L_TK_SYSTEM_CONFIG_DIRS:
        return luaH_push_path_array(L, g_get_system_config_dirs());

      default:
        break;
    }
    return 0;
}

void
xdg_lib_setup(lua_State *L)
{
    static const struct luaL_Reg xdg_lib[] =
    {
        { "__index", luaH_xdg_index },
        { NULL, NULL },
    };

    luaH_openlib(L, "xdg", xdg_lib, xdg_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
