/**
 * Copyright (c) Jason White
 *
 * MIT License
 *
 * Description:
 * Main program logic.
 */
#include <string.h>
#include <stdio.h>

#include "bblua.h"
#include "rules.h"
#include "path.h"

namespace {

const char* usage = "Usage: bblua <script> [-o output] [args...]\n";

struct Options
{
    const char* script;
    const char* output;
};

struct Args
{
    int n;
    char** argv;
};

/**
 * Parses command line arguments. Returns true if successful.
 */
bool parse_args(Options &opts, Args &args)
{
    if (args.n > 0) {
        opts.script = args.argv[0];
        --args.n; ++args.argv;

        if (args.n > 0 && strcmp(args.argv[0], "-o") == 0) {
            if (args.n > 1)
                opts.output = args.argv[1];
            else
                return false;

            args.n -= 2;
            args.argv += 2;
        }
        else {
            opts.output = NULL;
        }

        return true;
    }

    return false;
}

void print_error(lua_State* L)
{
    printf("Error: %s\n", lua_tostring(L, -1));
}

int rule(lua_State *L)
{
    bblua::Rules* rules = (bblua::Rules*)lua_touserdata(L, lua_upvalueindex(1));
    if (rules)
        rules->add(L);
    return 0;
}

}

namespace bblua {

int init(lua_State* L) {

    // Initialize the standard library
    luaL_openlibs(L);

    luaL_requiref(L, "path", luaopen_path, 1);
    lua_pop(L, 1);

    return 0;
}

int execute(lua_State* L, int argc, char** argv) {

    Options opts;
    Args args = {argc-1, argv+1};

    if (!parse_args(opts, args)) {
        fputs(usage, stderr);
        return 1;
    }

    if (luaL_loadfile(L, opts.script) != LUA_OK) {
        print_error(L);
        return 1;
    }

    FILE* output;

    if (!opts.output || strcmp(opts.output, "-") == 0)
        output = stdout;
    else
        output = fopen(opts.output, "w");

    if (!output) {
        perror("Failed to open output file");
        return 1;
    }

    Rules rules(output);

    // Register rule() function
    lua_pushlightuserdata(L, &rules);
    lua_pushcclosure(L, rule, 1);
    lua_setglobal(L, "rule");

    // Pass along the rest of the command line arguments to the Lua script.
    for (int i = 0; i < args.n; ++i)
        lua_pushstring(L, args.argv[i]);

    if (lua_pcall(L, args.n, LUA_MULTRET, 0) != LUA_OK) {
        print_error(L);
        return 1;
    }

    return 0;
}

}
