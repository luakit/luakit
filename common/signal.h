/*
 * signal.h - Signal handling functions
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright © 2009 Julien Danjou <julien@danjou.info>
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

#ifndef LUAKIT_COMMON_SIGNAL
#define LUAKIT_COMMON_SIGNAL

#include <glib/garray.h>
#include <glib/gstrfuncs.h>
#include <glib/gtestutils.h>
#include <glib/gtree.h>

#include "common/util.h"

typedef GTree      signal_t;
typedef GPtrArray  signal_array_t;

/* signals tree key compare function */
static inline gint
signal_cmp(gconstpointer a, gconstpointer b, gpointer UNUSED(p))
{
    return g_strcmp0(a, b);
}

/* signals tree data destroy function */
static inline void
signal_array_destroy(gpointer *sigfuncs)
{
    g_ptr_array_free((GPtrArray*) sigfuncs, TRUE);
}

/* create binary search tree for fast signal array lookups */
static inline signal_t*
signal_new(void)
{
    return (signal_t*) g_tree_new_full((GCompareDataFunc) signal_cmp,
        NULL, (GDestroyNotify) g_free, (GDestroyNotify) signal_array_destroy);
}

/* destory signals tree */
static inline void
signal_destroy(signal_t *signals)
{
    g_tree_destroy((GTree*) signals);
}

static inline signal_array_t*
signal_lookup(signal_t *signals, const gchar *name)
{
    return (signal_array_t*) g_tree_lookup((GTree*) signals, (gpointer) name);
}

/* add a signal inside a signal array */
static inline void
signal_add(signal_t *signals, const gchar *name, gpointer func)
{
    signal_array_t *sigfuncs = signal_lookup(signals, name);
    if (!sigfuncs) {
        sigfuncs = (signal_array_t*) g_ptr_array_new();
        g_tree_insert((GTree*) signals, (gpointer) g_strdup(name), sigfuncs);
    }
    g_ptr_array_add((GPtrArray*) sigfuncs, func);
}

/* remove a signal inside a signal array */
static inline void
signal_remove(signal_t *signals, const gchar *name, gpointer func)
{
    signal_array_t *sigfuncs = signal_lookup(signals, name);
    if (sigfuncs) {
        g_ptr_array_remove((GPtrArray*) sigfuncs, func);
        /* prune empty sigfuncs array from the tree */
        if (!sigfuncs->len)
            g_tree_remove((GTree*) signals, (gpointer) name);
    }
}

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
