--[[
 Copyright: Copyright Jason White, 2015
 License:   MIT
 Authors:   Jason White

 Description:
 Generates rules for the DMD compiler.
]]

local rules = require "rules"

--[[
Helper functions.

TODO: Alter paths based on platform
]]
local function is_d_source(src)
    local _,ext = path.splitext(src)
    return ext == ".d"
end

local function to_object(objdir, src)
    return path.join(objdir, src .. ".o")
end


-- Base metatable
local _base = {

    -- Path to DMD
    compiler = {"dmd"};

    -- Extra options
    opts = {"-color=on"};

    -- Path to the bin directory
    bindir = "./bin";

    -- Build all source on the same command line
    combined = true;

    -- Paths to look for imports
    imports = {};

    -- Paths to look for string imports
    string_imports = {};

    -- Versions to define with '-version='
    versions = {};

    -- Extra compiler and linker options
    compiler_opts = {};
    linker_opts = {};
}

--[[
Returns the path to the target
]]
function _base:path()
    return path.join(self.bindir, self.name)
end

setmetatable(_base, {__index = rules.base})

local _binary = {}
local _binary_mt = {__index = _binary}
setmetatable(_binary, {__index = _base})

local _library = {}
local _library_mt = {__index = _library}
setmetatable(_library, {__index = _base})

function _library:path()
    return path.join(self.bindir, self.name .. ".a")
end

--[[
Generates the low-level rules required to build a generic D library/binary.
]]
function _base:rules(deps)
    local objdir = self.objdir or path.join("obj", self.name)

    local args = table.join(self.prefix, self.compiler, self.opts)

    local compiler_opts = {}

    for _,v in ipairs(self.imports) do
        table.insert(compiler_opts, "-I" .. v)
    end

    for _,v in ipairs(self.string_imports) do
        table.insert(compiler_opts, "-J" .. v)
    end

    for _,v in ipairs(self.versions) do
        table.insert(compiler_opts, "-version=" .. v)
    end

    table.append(compiler_opts, self.compiler_opts)

    local sources = {}
    local objects = {}
    for _,v in ipairs(self.srcs) do
        if is_d_source(v) then
            table.insert(sources, v)
            table.insert(objects, to_object(objdir, v))
        end
    end

    local inputs = {}
    table.append(inputs, sources)

    for _,dep in ipairs(deps) do
        if getmetatable(dep) == _library_mt then
            table.insert(inputs, dep:path())
        end
    end

    local output = self:path()

    local linker_opts = table.join(self.linker_opts, {"-of" .. output})

    -- Combined compilation
    rule {
        inputs  = inputs,
        task    = table.join(args, linker_opts, compiler_opts, inputs),
        outputs = {output}
    }
end

--[[
A D binary.
]]
local function binary(opts)

    setmetatable(opts, _binary_mt)

    return rules.add(opts)
end

local function library(opts)

    setmetatable(opts, _library_mt)

    return rules.add(opts)
end

return {
    _base = _base,
    _binary_mt  = _binary_mt,
    _library_mt = _library_mt,

    binary = binary,
    library = library,
}
