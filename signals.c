/*
 * signals.c - signal hash table constructors/destructors
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
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

#include "luakit.h"
#include "util.h"
#include "signals.h"

static void
destroy_key(gpointer data) {
    debug("Freeing signals array key %s", data);
    g_free(data);
}

static void
destroy_ptr_array(gpointer data) {
    debug("Freeing signals ptr array at %p", data);
    g_ptr_array_free(data, TRUE);
}

GHashTable*
signals_table_new(void) {
    return g_hash_table_new_full(g_str_hash, g_str_equal,
        (GDestroyNotify) destroy_key, (GDestroyNotify) destroy_ptr_array);
}
