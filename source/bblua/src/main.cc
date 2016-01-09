/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Program entry point.
 */
#include <iostream>

#include "bblua.h"

int main(int argc, char **argv) {
    lua_State *L = luaL_newstate();
    if (!L) return 1;

    int ret;

    ret = bblua::init(L);

    if (ret == 0)
        ret = bblua::execute(L, argc, argv);

    lua_close(L);

    return ret;
}
