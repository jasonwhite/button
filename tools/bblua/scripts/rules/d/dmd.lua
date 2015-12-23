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

--[[
Base metatable
]]
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

--[[
A binary executable.
]]
local _binary = {
}

local _binary_mt = {__index = _binary}

local function is_binary(t)
    return getmetatable(t) == _binary_mt
end

setmetatable(_binary, {__index = _base})

--[[
A library. Can be static or dynamic.
]]
local _library = {
    -- Shared library?
    shared = false,
}

local _library_mt = {__index = _library}

local function is_library(t)
    return getmetatable(t) == _library_mt
end

setmetatable(_library, {__index = _base})

--[[
Generates the low-level rules required to build a generic D library/binary.
]]
function _base:rules(deps)
    local objdir = self.objdir or path.join("obj", self.name)

    local args = table.join(self.prefix, self.compiler, self.opts)

    local compiler_opts = {"-op", "-od".. objdir}

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
        if is_library(dep) then
            table.insert(inputs, dep:path())
        end
    end

    local output = self:path()

    local linker_opts = table.join(self.linker_opts, {"-of" .. output})

    -- Combined compilation
    rule {
        inputs  = inputs,
        task    = table.join(args, compiler_opts, linker_opts, inputs),
        outputs = table.join(objects, {output}),
    }
end

function _library:path()
    if self.shared then
        return path.join(self.bindir, self.name .. ".so")
    else
        return path.join(self.bindir, self.name .. ".a")
    end
end

function _library:rules(deps)
    if self.shared then
        table.insert(self.linker_opts, "-shared")
    else
        table.insert(self.linker_opts, "-lib")
    end

    _base.rules(self, deps)
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

    is_binary = is_binary,
    is_library = is_library,

    binary = binary,
    library = library,
}
