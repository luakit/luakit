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

#ifndef LUAKIT_SOUP_AUTH_H
#define LUAKIT_SOUP_AUTH_H

#define TYPE_SOUP_AUTH_FEATURE            (soup_auth_feature_get_type ())
#define SOUP_AUTH_FEATURE(object)         (G_TYPE_CHECK_INSTANCE_CAST ((object), TYPE_SOUP_AUTH_FEATURE, SoupAuthFeature))
#define SOUP_AUTH_FEATURE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_SOUP_AUTH_FEATURE, SoupAuthFeature))
#define IS_SOUP_AUTH_FEATURE(object)      (G_TYPE_CHECK_INSTANCE_TYPE ((object), TYPE_SOUP_AUTH_FEATURE))
#define IS_SOUP_AUTH_FEATURE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_SOUP_AUTH_FEATURE))
#define SOUP_AUTH_FEATURE_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_SOUP_AUTH_FEATURE, SoupAuthFeature))

typedef struct {
    GObject parent_instance;
} SoupAuthFeature;

typedef struct {
    GObjectClass parent_class;
} SoupAuthFeatureClass;

GType soup_auth_feature_get_type();

SoupAuthFeature* soup_auth_feature_new();
void soup_auth_feature_resume_authentication(const char *username, const char *password);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
