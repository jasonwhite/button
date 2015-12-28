--[[
Copyright (c) Jason White, 2015
License: MIT

Description:
Generates the build description.
]]

local d = require "rules.d.dmd"

-- Wrap all commands with the bootstrapped wrapper to catch dependencies.
d.base.prefix = {"./bb-wrap-bootstrap"}

-- Compiler flags for all targets
d.base.compiler_opts = {"-release", "-w"}

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
