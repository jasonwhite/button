--[[
 Copyright: Copyright Jason White, 2015
 License:   MIT
 Authors:   Jason White

 Description:
 This file is the first Lua script that gets executed. Its job is to initialize
 the global Lua state for client scripts.
]]

-- Remove functions that can affect the file system.
io.popen   = nil
io.tmpfile = nil
os.execute = nil
os.tmpname = nil
os.rename  = nil
os.remove  = nil

-- Override io.open to prevent writing to files.
local _open = io.open
io.open = function(filename, mode)
    if mode ~= "" and mode ~= "r" and mode ~= "rb" then
        error("can only open files in read mode")
    end

    -- TODO: Report dependency on the file

    return _open(filename, mode)
end

-- TODO: Override 'loadfile', 'dofile', and 'require' to catch dependencies


