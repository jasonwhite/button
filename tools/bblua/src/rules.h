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
    int add(lua_State *L);

private:
    int fieldToJSON(lua_State *L, int tbl, const char* field, size_t i);

private:
    // File handle to write to.
    FILE* _f;

    // Number of rules.
    size_t _n;
};


}
