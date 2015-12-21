local t = {}

-- Mapping of names to targets.
t.targets = {}

--[[
    Base metatable for all rules to "inherit" from.
]]
t.base = {
    -- Name of the target
    name = "",

    -- Command line prefix.
    prefix = {},

    -- List of dependencies
    deps = {},

    -- List of source files
    srcs = {},
}

--[[
    Adds a target to the table.
]]
function t.add(target)
    table.insert(t.targets, target)
    return target
end

--[[
    Resolve dependencies. For all targets, the .rules method is called with the
    set of dependencies.
]]
function t.resolve()

    local index = {}

    for k,v in ipairs(t.targets) do
        assert(not index[v.name], "Target name '".. v.name .."' is not unique")
        index[v.name] = v
    end

    -- Resolve dependencies
    for k,v in ipairs(t.targets) do
        local deps = {}
        for _,dep in ipairs(v.deps) do
            local d = index[dep]
            assert(d, string.format("Dependency '%s' does not exist for target '%s'", dep, v.name))
            table.insert(deps, d)
        end

        v:rules(deps)
    end
end

return t
