/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Handles writing out rules.
 */
#pragma once

#include <stdio.h>

struct lua_State;

namespace bblua {

class Rules
{
public:
    Rules(FILE* f);
    ~Rules();

    /**
     * Outputs a rule to the file.
     */
    void add(lua_State *L);

private:
    FILE* _f;
};


}
