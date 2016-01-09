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

namespace {

const char  escape_chars[] = {'\"',   '\t',  '\r',  '\n',  '\b',  '\\',  '\0'};
const char* replacements[] = {"\\\"", "\\t", "\\r", "\\n", "\\b", "\\\\", NULL};

/**
 * For the given character, returns the equivalent JSON escape sequence. If the
 * given character is not a character to be escaped, returns NULL.
 */
const char* json_escape_sequence(char c) {
    for (size_t i = 0; escape_chars[i] != '\0'; ++i) {
        if (escape_chars[i] == c)
            return replacements[i];
    }

    return NULL;
}

/**
 * Escapes the given string that will be output to JSON. The resulting string is
 * left at the top of the stack.
 */
int json_escaped_string(lua_State *L, const char* s, size_t len) {

    size_t newlen = len;

    // Calculate the new size of the escaped string
    for (size_t i = 0; i < len; ++i) {
        if (json_escape_sequence(s[i]))
            ++newlen;
    }

    luaL_Buffer b;
    char* buf = luaL_buffinitsize(L, &b, newlen);
    size_t j = 0;

    for (size_t i = 0; i < len; ++i) {
        if (const char* r = json_escape_sequence(s[i])) {
            buf[j++] = r[0];
            buf[j++] = r[1];
            continue;
        }

        buf[j++] = s[i];
    }

    luaL_pushresultsize(&b, newlen);

    return 1;
}

}

namespace bblua {

Rules::Rules(FILE* f) : _f(f), _n(0) {
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

                json_escaped_string(L, s, len);
                const char* escaped = lua_tolstring(L, -1, &len);

                fputs("\"", _f);
                fwrite(escaped, 1, len, _f);
                fputs("\"", _f);

                lua_pop(L, 1); // Pop escaped string

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
