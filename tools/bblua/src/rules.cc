/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Handles writing out rules.
 */
#include "lua.hpp"

#include "rules.h"

namespace bblua {

Rules::Rules(FILE* f) : _f(f)
{
    fputs("[\n", _f);
}

Rules::~Rules() {
    fputs("]\n", _f);
}

void Rules::add(lua_State *L) {
    // TODO
}

}
