/*
 * tabs.h - root notebook widget wrapper
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2007-2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_TABS_H
#define LUAKIT_TABS_H

#include "luakit.h"

static inline void
luaH_checktabindex(gint i) {
    if(i < 0 || i >= gtk_notebook_get_n_pages(GTK_NOTEBOOK(luakit.nbook)))
        luaL_error(luakit.L, "invalid tab index: %d", i + 1);
}

extern const struct luaL_reg luakit_tabs_methods[];
extern const struct luaL_reg luakit_tabs_meta[];

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:enc=utf-8:tw=80
