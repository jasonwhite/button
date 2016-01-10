--[[
Copyright 2016 Jason White. MIT license.
]]

-- Basic checks to see if certain modules exist.
assert(type(path) == "table")

-- Test that certain functions that can affect the file system don't exist.
assert(io.popen == nil)
assert(io.tmpfile == nil)
assert(io.output == nil)
assert(os.execute == nil)
assert(os.tmpname == nil)
assert(os.rename == nil)
assert(os.remove == nil)
assert(package.loadlib == nil)
assert(#package.searchers == 3)
