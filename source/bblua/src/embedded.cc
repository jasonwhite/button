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
#define SCRIPT(module, path, name) \
    {(module), (path), scripts_ ## name ## _lua, scripts_ ## name ## _lua_len}

namespace {

struct Script
{
    const char* name;
    const char* path;
    const void* data;
    size_t length;

    // Loads this Lua script
    int load(lua_State* L) const;
};

/**
 * Main scripts
 */
#include "embedded/init.c"
#include "embedded/shutdown.c"

/**
 * Initialization/shutdown scripts.
 */
const Script script_init     = SCRIPT("init", "init.lua", init);
const Script script_shutdown = SCRIPT("shutdown", "shutdown.lua", shutdown);

/**
 * Modules to embed
 */
#include "embedded/rules.c"
#include "embedded/rules/cc.c"
#include "embedded/rules/cc/gcc.c"
#include "embedded/rules/d.c"
#include "embedded/rules/d/dmd.c"

/**
 * List of embedded Lua scripts.
 *
 * NOTE: This must be in alphabetical order according to the Lua script path.
 */
const Script embedded[] = {
    SCRIPT("rules", "{embedded}/rules.lua", rules),
    SCRIPT("rules.cc", "{embedded}/rules/cc.lua", rules_cc),
    SCRIPT("rules.cc.gcc", "{embedded}/rules/cc/gcc.lua", rules_cc_gcc),
    SCRIPT("rules.d", "{embedded}/rules/d.lua", rules_d),
    SCRIPT("rules.d.dmd", "{embedded}/rules/d/dmd.lua", rules_d_dmd),
};

const size_t embedded_len = sizeof(embedded)/sizeof(Script);

int compare_embedded(const void* key, const void* elem) {
    return strcmp((const char*)key, ((const Script*)elem)->name);
}

// Note that this assumes the list of modules is sorted.
const Script* find_embedded(const char* name) {
    return (const Script*)bsearch(name, embedded, embedded_len, sizeof(Script), compare_embedded);
}

int Script::load(lua_State* L) const {
    return luaL_loadbuffer(L, (const char*)data, length, name);
}

} // namespace

int load_embedded(lua_State* L, const char* name)
{
    const Script* m = find_embedded(name);

    if (!m) {
        lua_pushfstring(L, "embedded script '%s' not found", name);
        return LUA_ERRFILE;
    }

    return m->load(L);
}

int embedded_searcher(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);

    const Script* m = find_embedded(name);

    if (!m) {
        lua_pushfstring(L, "embedded script '%s' not found", name);
        return 1;
    }

    // Return block function + file name to pass to it
    if (m->load(L))
        return 1;

    lua_pushstring(L, m->path);
    return 2;
}

int load_init(lua_State* L) {
    return script_init.load(L);
}

int load_shutdown(lua_State* L) {
    return script_shutdown.load(L);
}
