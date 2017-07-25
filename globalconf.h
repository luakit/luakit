/*
 * globalconf.h - main config struct
 *
 * Copyright © 2010 Mason Larobina <mason.larobina@gmail.com>
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

#ifndef LUAKIT_GLOBALCONF_H
#define LUAKIT_GLOBALCONF_H

#include "buildopts.h"
#include "common/common.h"

#include <glib.h>
#include <gtk/gtk.h>
#include <lua.h>

/** Global luakit state struct. */
typedef struct {
    /** GTK application */
    GtkApplication *application;

    /** User path $XDG_CONFIG_DIR/luakit/ (defaults to ~/.config/luakit/) where
     * configuration files should be stored.
     * \see http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html */
    gchar *config_dir;
    /** User path $XDG_DATA_DIR/luakit/ (defaults to ~/.local/share/luakit/)
     * where data files should be stored.
     * \see http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html */
    gchar *data_dir;
    /** User path $XDG_CACHE_DIR/luakit/ (defaults to ~/.cache/luakit/) where
     * non-essential data files should be stored.
     * \see http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html */
    gchar *cache_dir;
    /** Profile name */
    gchar *profile;

    /** Path to the currently loaded config file. */
    gchar *confpath;
    /** The luakit executable path. */
    gchar *execpath;
    /** Ignore loading libunqiue bindings (for a single instance session) */
    gboolean nounique;
    /** Arguments provided to luakit */
    GPtrArray *argv;

    /** Pointer array to all active window userdata objects. */
    GPtrArray *windows;
    /** Pointer array to all active webview userdata objects. */
    GPtrArray *webviews;
    /** Pointer array to all user stylesheets. */
    GPtrArray *stylesheets;

    /** Start time for debug messages */
    gdouble starttime;
} globalconf_t;

globalconf_t globalconf;

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
