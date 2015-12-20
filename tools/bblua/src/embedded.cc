/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Path manipulation module.
 */
#include "embedded.h"

#include <string.h> // for strcmp
#include <stdlib.h> // for bsearch

#include <lua.hpp>

// Helper macro for adding new modules
#define SCRIPT(path, name) \
    {(path), scripts_ ## name ## _lua, scripts_ ## name ## _lua_len}

namespace {

struct Script
{
    const char* name;
    const void* data;
    size_t length;
};

/**
 * Scripts to include.
 */
#include "embedded/init.c"
#include "embedded/shutdown.c"

/**
 * List of embedded Lua scripts.
 *
 * NOTE: This must be in alphabetical order according to the Lua script path.
 */
const Script embedded[] = {
    SCRIPT("init.lua", init),
    SCRIPT("shutdown.lua", shutdown),
};

const size_t embedded_len = sizeof(embedded)/sizeof(Script);

int compare_embedded(const void* key, const void* elem) {
    return strcmp((const char*)key, ((const Script*)elem)->name);
}

// Note that this assumes the list of modules is sorted.
const Script* find_embedded(const char* name) {
    return (const Script*)bsearch(name, embedded, embedded_len, sizeof(Script), compare_embedded);
}

} // namespace

int embedded_searcher(lua_State *L) {
    const char* name = luaL_checkstring(L, 1);

    const Script* m = find_embedded(name);

    if (!m) {
        // TODO: Return error message instead
        lua_pushnil(L);
        return 1;
    }

    // Return open function + file name to pass to it
    luaL_loadbuffer(L, (const char*)m->data, m->length, m->name);
    lua_pushstring(L, m->name);
    return 2;
}
