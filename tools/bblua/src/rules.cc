/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Handles writing out rules.
 */
#include "lua.hpp"

#include <stdio.h>
#include "rules.h"


namespace bblua {

Rules::Rules(FILE* f) : _f(f), _n(0)
{
    fputs("[", _f);
}

Rules::~Rules() {
    fputs("\n]\n", _f);
}

int Rules::add(lua_State *L) {

    luaL_checktype(L, 1, LUA_TTABLE);

    if (_n > 0)
        fputs(",", _f);

    fputs("\n    {", _f);

    fieldToJSON(L, 1, "inputs", 0);
    fieldToJSON(L, 1, "task", 1);
    fieldToJSON(L, 1, "outputs", 2);

    fputs("\n    }", _f);

    ++_n;

    return 0;
}

int Rules::fieldToJSON(lua_State *L, int tbl, const char* field, size_t i) {

    // Which element we're on.
    size_t element = 0;

    if (i > 0)
        fputs(",", _f);

    fprintf(_f, "\n        \"%s\": [", field);

    if (lua_getfield(L, tbl, field) == LUA_TTABLE) {

        size_t len; // Length of the string

        for (int i = 1; ; ++i) {

            if (lua_rawgeti(L, -1, i) == LUA_TNIL) {
                lua_pop(L, 1);
                break;
            }

            const char* s = lua_tolstring(L, -1, &len);
            if (s) {
                if (element > 0)
                    fputs(", ", _f);

                const char* sanitized = luaL_gsub(L, s, "\"", "\\\"");

                fputs("\"", _f);
                fwrite(sanitized, 1, len, _f);
                fputs("\"", _f);

                lua_pop(L, 1); // Pop gsub string

                ++element;
            }
            else {
                return luaL_error(L,
                        "bad type in table for field '%s' (string expected, got %s)",
                        field, luaL_typename(L, -1));
            }

            lua_pop(L, 1); // Pop table element
        }
    }
    else {
        return luaL_error(L, "bad type for field '%s' (table expected, got %s)",
                field, luaL_typename(L, -1));
    }

    lua_pop(L, 1);

    fputs("]", _f);

    return 0;
}

}
