/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Main program logic.
 */
#pragma once

#include "lua.hpp"

namespace bblua {

/**
 * Initializes the Lua state with additional functions and libraries.
 */
int init(lua_State* L);

/**
 * Executes the script given on the command line. Fails if no script is given.
 */
int execute(lua_State* L, int argc, char **argv);

}
