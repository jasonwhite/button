--[[
Copyright (c) Jason White. MIT license.

Description:
This file is the last Lua script that gets executed.
]]

local rules = require "rules"

rules.resolve()
