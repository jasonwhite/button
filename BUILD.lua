--[[
Copyright (c) Jason White, 2016
License: MIT

Description:
Generates the build description.
]]

local d = require "rules.d"
local cc = require "rules.cc"

-- Wrap all commands with the bootstrapped wrapper to catch dependencies.
d.common.prefix = {"./bb-wrap-bootstrap"}

-- Compiler flags for all targets
d.common.compiler_opts = {"-release", "-w"}

d.library {
    name = "io",
    srcs = fs.glob "source/io/source/io/**/*.d",
    imports = {"source/io/source"},
}

d.test {
    name = "io_test",
    srcs = fs.glob "source/io/source/io/**/*.d",
    imports = {"source/io/source"},
    linker_opts = {"-main"},
}

d.binary {
    name = "bb",
    deps = {"io"},
    srcs = fs.glob {
        "source/util/*.d",
        "source/bb/**/*.d",
        "source/darg/source/*.d",
        },
    imports = {"source", "source/darg/source", "source/io/source"},
    linker_opts = {"-L-lsqlite3"},
}

d.test {
    name = "bb_test",
    deps = {"io"},
    srcs = fs.glob {
        "source/util/*.d",
        "source/bb/**/*.d",
        "source/darg/source/*.d",
        },
    imports = {"source", "source/darg/source", "source/io/source"},
    linker_opts = {"-L-lsqlite3"},
}

d.binary {
    name = "bbwrapper",
    deps = {"io"},
    srcs = fs.glob "source/wrap/source/wrap/**/*.d",
    imports = {"source/wrap/source", "source/io/source"},
}

d.test {
    name = "bbwrapper_test",
    deps = {"io"},
    srcs = fs.glob "source/wrap/source/wrap/**/*.d",
    imports = {"source/wrap/source", "source/io/source"},
}

cc.library {
    name = "lua:static",
    static = true,
    srcs = fs.glob {
        "tools/bblua/contrib/lua-5.3.2/src/*.c",
        "!tools/bblua/contrib/lua-5.3.2/src/lua.c",
        "!tools/bblua/contrib/lua-5.3.2/src/luac.c",
        },
    compiler_opts = {"-std=gnu99", "-O2", "-Wall", "-Wextra", "-DLUA_COMPAT_5_2"},
    defines = {"LUA_USE_LINUX"},
}

cc.binary {
    name = "bblua",
    deps = {"lua:static"},
    srcs = fs.glob "tools/bblua/src/*.cc",
    includes = {"tools/bblua/contrib/lua/include"},
    compiler_opts = {"-g", "-Wall", "-Werror"},
    linker_opts = {"-dl"},
}
