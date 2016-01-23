--[[
Copyright (c) Jason White, 2016
License: MIT

Description:
Generates the build description.
]]

import "source/bblua/BUILD.lua"

local d = require "rules.d"

-- Compiler flags for all targets
d.common.compiler_opts = {"-release", "-w"}

d.library {
    name = "io",
    srcs = glob "source/io/source/io/**/*.d",
    imports = {"source/io/source"},
}

d.test {
    name = "io_test",
    srcs = glob "source/io/source/io/**/*.d",
    imports = {"source/io/source"},
    linker_opts = {"-main"},
}

d.binary {
    name = "bb",
    deps = {"io"},
    srcs = glob {
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
    srcs = glob {
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
    srcs = glob "source/wrap/source/wrap/**/*.d",
    imports = {"source/wrap/source", "source/io/source"},
}

d.test {
    name = "bbwrapper_test",
    deps = {"io"},
    srcs = glob "source/wrap/source/wrap/**/*.d",
    imports = {"source/wrap/source", "source/io/source"},
}
