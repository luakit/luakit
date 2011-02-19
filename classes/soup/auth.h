/*
 * classes/soup/auth.h - authentication management header
 *
 * Copyright (C) 2009 Igalia S.L.
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

#ifndef LUAKIT_CLASSES_SOUP_AUTH_H
#define LUAKIT_CLASSES_SOUP_AUTH_H

#include <gtk/gtk.h>
#include <libsoup/soup.h>

#define LUAKIT_TYPE_AUTH_DIALOG            (luakit_auth_dialog_get_type ())
#define LUAKIT_AUTH_DIALOG(object)         (G_TYPE_CHECK_INSTANCE_CAST ((object), LUAKIT_TYPE_AUTH_DIALOG, LuakitAuthDialog))
#define LUAKIT_AUTH_DIALOG_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass),     LUAKIT_TYPE_AUTH_DIALOG, LuakitAuthDialog))
#define LUAKIT_IS_AUTH_DIALOG(object)      (G_TYPE_CHECK_INSTANCE_TYPE ((object), LUAKIT_TYPE_AUTH_DIALOG))
#define LUAKIT_IS_AUTH_DIALOG_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass),     LUAKIT_TYPE_AUTH_DIALOG))
#define LUAKIT_AUTH_DIALOG_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj),     LUAKIT_TYPE_AUTH_DIALOG, LuakitAuthDialog))

typedef struct {
    GObject parent_instance;
} LuakitAuthDialog;

typedef struct {
    GObjectClass parent_class;
} LuakitAuthDialogClass;

GType luakit_auth_dialog_get_type();
LuakitAuthDialog *luakit_auth_dialog_new();

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
