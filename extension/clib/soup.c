/*
 * extension/clib/soup.c - soup library
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

#include "luah.h"
#include "clib/soup.h"
#include "common/property.h"
#include "common/signal.h"
#include "web_context.h"

#include <libsoup/soup.h>
#include <webkit2/webkit2.h>

static lua_class_t soup_class;
LUA_CLASS_FUNCS(soup, soup_class);

#include "common/clib/soup.h"

void
soup_lib_setup(lua_State *L)
{
    soup_lib_setup_common();

    static const struct luaL_Reg soup_lib[] =
    {
        LUA_CLASS_METHODS(soup)
        { "parse_uri",     luaH_soup_parse_uri },
        { "uri_tostring",  luaH_soup_uri_tostring },
        { NULL,            NULL },
    };

    /* create signals array */
    soup_class.signals = signal_new();

    /* export soup lib */
    luaH_openlib(L, "soup", soup_lib, soup_lib);
}

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
