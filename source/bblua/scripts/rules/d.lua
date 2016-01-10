--[[
Copyright (c) Jason White. MIT license.

Description:
Returns the appropriate tool chain for the current platform.
]]

-- For D, this is always DMD.
return require("rules.d.dmd")
