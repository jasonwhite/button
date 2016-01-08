--[[
Copyright 2016 Jason White. MIT license.

Description:
Generates the build description for a simple "foobar" program.
]]

local cc = require "rules.cc"

cc.binary {
    name = "foobar",
    srcs = glob "*.c",
}
