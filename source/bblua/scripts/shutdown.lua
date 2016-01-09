--[[
 Copyright: Copyright Jason White, 2016
 License:   MIT
 Authors:   Jason White

 Description:
 This file is the last Lua script that gets executed.
]]

local rules = require "rules"

rules.resolve()
