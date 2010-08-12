/*
 * signal.h - Signal handling functions
 *
 * Copyright (C) 2010 Mason Larobina <mason.larobina@gmail.com>
 * Copyright (C) 2009 Julien Danjou <julien@danjou.info>
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

#include <glib/gstrfuncs.h>
#include <glib/garray.h>
#include <glib/gtree.h>

#include "common/util.h"

typedef GTree      signal_t;
typedef GPtrArray  signal_array_t;

/* wrapper around g_ptr_array_new */
static inline signal_array_t *
signal_array_new(void) {
    return (signal_array_t *) g_ptr_array_new();
}

/* wrapper around g_ptr_array_remove */
static inline void
signal_array_remove(signal_array_t *sigfuncs, gpointer ref) {
    g_ptr_array_remove((GPtrArray *) sigfuncs, ref);
}

/* wrapper around g_ptr_array_free */
static inline void
signal_array_destroy(signal_array_t *sigfuncs) {
    if (sigfuncs)
        g_ptr_array_free((GPtrArray * )sigfuncs, TRUE);
    sigfuncs = NULL;
}

/* wrapper around g_ptr_array_add */
static inline void
signal_array_insert(signal_array_t *sigfuncs, gpointer ref) {
    g_ptr_array_add((GPtrArray *) sigfuncs, ref);
}

/* wrapper around g_tree_new */
static inline signal_t *
signal_tree_new(void) {
    return (signal_t *) g_tree_new((GCompareFunc) strcmp);
}

/* wrapper around g_tree_remove */
static inline void
signal_tree_remove(signal_t *signals, const gchar *name) {
    g_tree_remove((GTree *) signals, (gpointer) name);
}

/* wrapper around g_tree_destroy */
static inline void
signal_tree_destroy(signal_t *signals) {
    if (signals)
        g_tree_destroy((GTree *) signals);
    signals = NULL;
}

static inline signal_array_t *
signal_lookup(signal_t *signals, const gchar *name, gboolean create) {
    if (!signals) return NULL;

    signal_array_t *sigfuncs = g_tree_lookup((GTree *) signals,
            (gpointer) name);

    /* create if asked and not found */
    if (create && !sigfuncs) {
        sigfuncs = signal_array_new();
        g_tree_insert((GTree *) signals, (gpointer) g_strdup(name), sigfuncs);
    }
    return sigfuncs;
}

static inline void
signal_add(signal_t *signals, const gchar *name, gpointer ref) {
    /* find ptr array for this signal */
    signal_array_t *sigfuncs = signal_lookup(signals, name, TRUE);
    /* add the handler to this signals ptr array */
    g_ptr_array_add((GPtrArray *) sigfuncs, ref);
}

static inline void
signal_remove(signal_t *signals, const gchar *name, gpointer ref) {
    if(!signals) return;
    /* try to find ptr array for this signal */
    signal_array_t *sigfuncs = signal_lookup(signals, name, FALSE);
    /* remove the signal handler if found */
    if (sigfuncs)
        signal_array_remove(sigfuncs, ref);
    /* remove empty sigfuncs array from signals */
    if (!sigfuncs->len)
        signal_tree_remove(signals, name);
}

#endif
// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
