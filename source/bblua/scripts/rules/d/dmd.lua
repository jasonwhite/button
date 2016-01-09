--[[
Copyright 2016 Jason White. MIT license.

Description:
Generates rules for the DMD compiler.
]]

local rules = require "rules"

--[[
Helper functions.

TODO: Alter paths based on platform
]]
local function is_d_source(src)
    return path.getext(src) == ".d"
end

local function to_object(objdir, src)
    return path.join(objdir, src .. ".o")
end

--[[
Base metatable
]]
local common = {

    -- Path to DMD
    compiler = {"dmd"};

    -- Extra options
    opts = {"-color=on"};

    -- Path to the bin directory
    bindir = ".";

    -- Build all source on the same command line. Otherwise, each source is
    -- compiled separately and finally linked separately. In general, combined
    -- compilation is faster.
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

function common:path()
    return path.join(self.bindir, self:basename())
end

setmetatable(common, {__index = rules.common})

--[[
A binary executable.
]]
local _binary = {}

local _binary_mt = {__index = _binary}

local function is_binary(t)
    return getmetatable(t) == _binary_mt
end

setmetatable(_binary, {__index = common})

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

setmetatable(_library, {__index = common})

--[[
A test.
]]
local _test = {}
local _test_mt = {__index = _test}

local function is_test(t)
    return getmetatable(t) == _test_mt
end

setmetatable(_test, {__index = common})


--[[
Generates the low-level rules required to build a generic D library/binary.
]]
function common:rules()
    local objdir = self.objdir or path.join("obj", self.name)

    local args = table.join(self.prefix, self.compiler, self.opts)

    local compiler_opts = {"-op"}

    for _,v in ipairs(self.imports) do
        table.insert(compiler_opts, "-I" .. path.join(SCRIPT_DIR, v))
    end

    for _,v in ipairs(self.string_imports) do
        table.insert(compiler_opts, "-J" .. path.join(SCRIPT_DIR, v))
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

    -- TODO: Allow linking with C/C++ libraries
    for _,dep in ipairs(self.deps) do
        if is_library(dep) then
            table.insert(inputs, dep:path())
        end
    end

    local output = self:path()

    local linker_opts = table.join(self.linker_opts, {"-of" .. output})

    if self.combined then
        -- Combined compilation
        rule {
            inputs  = inputs,
            task    = table.join(args, compiler_opts, linker_opts, inputs),
            outputs = table.join(objects, {output}),
        }
    else
        -- Individual compilation
        for i,src in ipairs(sources) do
            rule {
                inputs  = {src},
                task    = table.join(args, compiler_opts,
                    {"-c", src, "-of".. objects[i]}),
                outputs = {objects[i]},
            }
        end

        rule {
            inputs = objects,
            task = table.join(args, linker_opts, objects),
            outputs = table.join(objects, {output}),
        }
    end
end

function _library:basename()
    local name = common.basename(self)

    if self.shared then
        return "lib".. name .. ".so"
    else
        return "lib".. name .. ".a"
    end
end

function _library:rules()
    if self.shared then
        self.linker_opts = table.join(self.linker_opts, "-shared")
    else
        self.linker_opts = table.join(self.linker_opts, "-lib")
    end

    common.rules(self)
end

function _test:rules()
    self.compiler_opts = table.join(self.compiler_opts, "-unittest")

    common.rules(self)

    local test_runner = self:path()

    rule {
        inputs  = {test_runner},
        task    = {test_runner},
        outputs = {},
    }
end

local function binary(opts)
    setmetatable(opts, _binary_mt)
    return rules.add(opts)
end

local function library(opts)
    setmetatable(opts, _library_mt)
    return rules.add(opts)
end

local function test(opts)
    setmetatable(opts, _test_mt)
    return rules.add(opts)
end

return {
    common = common,

    is_binary = is_binary,
    is_library = is_library,
    is_test = is_test,

    binary = binary,
    library = library,
    test = test,
}
