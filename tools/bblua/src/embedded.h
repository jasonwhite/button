/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Access to embedded Lua files.
 */
#pragma once

struct lua_State {};

int embedded_searcher(lua_State *L);

int load_embedded(lua_State* L, const char* name);

/**
 * Loads the embedded initialization script.
 */
int load_init(lua_State* L);

/**
 * Loads the embedded shutdown script.
 */
int load_shutdown(lua_State* L);
