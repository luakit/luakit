/*
 * soup_auth.h - authentication management header
 *
 * Copyright (C) 2010 Fabian Streitel <karottenreibe@gmail.com>
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

#include <gtk/gtk.h>
#include <libsoup/soup.h>

#include "luakit.h"
#include "classes/widget.h"

#ifndef LUAKIT_SOUP_AUTH_H
#define LUAKIT_SOUP_AUTH_H

G_BEGIN_DECLS

#define TYPE_LUAKIT_SOUP_AUTH            (luakit_soup_auth_get_type ())
#define LUAKIT_SOUP_AUTH(object)         (G_TYPE_CHECK_INSTANCE_CAST ((object), TYPE_LUAKIT_SOUP_AUTH, LuakitSoupAuth))
#define LUAKIT_SOUP_AUTH_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_LUAKIT_SOUP_AUTH, LuakitSoupAuth))
#define IS_LUAKIT_SOUP_AUTH(object)      (G_TYPE_CHECK_INSTANCE_TYPE ((object), TYPE_LUAKIT_SOUP_AUTH))
#define IS_LUAKIT_SOUP_AUTH_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_LUAKIT_SOUP_AUTH))
#define LUAKIT_SOUP_AUTH_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_LUAKIT_SOUP_AUTH, LuakitSoupAuth))

typedef struct {
    GObject parent_instance;
    widget_t *w;
} LuakitSoupAuth;

typedef struct {
    GObjectClass parent_class;
} LuakitSoupAuthClass;

GType luakit_soup_auth_get_type (void);

G_END_DECLS

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
