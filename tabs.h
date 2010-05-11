#ifndef LUAKIT_TABS_H
#define LUAKIT_TABS_H

#include "luakit.h"

#define luaH_checktabindex(i) \
    do { \
        if(i < 0 || i >= gtk_notebook_get_n_pages(GTK_NOTEBOOK(luakit.nbook))) \
            luaL_error(L, "invalid tab index: %d", i + 1); \
    } while(0)

extern const struct luaL_reg luakit_tabs_methods[];
extern const struct luaL_reg luakit_tabs_meta[];


#endif
