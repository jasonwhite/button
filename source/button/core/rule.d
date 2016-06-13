/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Parses rules.
 */
module button.core.rule;

import std.range.primitives : isInputRange, ElementType;

import button.core.command;
import button.core.resource;
import button.core.task;
import button.core.edge;

struct Rule
{
    /**
     * The sets of inputs and outputs that this task is dependent on.
     */
    Resource[] inputs, outputs;

    /**
     * The command to execute.
     */
    Task task;
}

struct Rules
{
    import std.json : JSONValue;

    private
    {
        JSONValue[] rules;

        // Current rule taken from the stream.
        Rule rule;

        bool _empty;
    }

    this(JSONValue rules)
    {
        this.rules = rules.array();

        // Prime the cannon
        popFront();
    }

    void popFront()
    {
        import std.range : empty, popFront, front;
        import std.algorithm : map;
        import std.array : array;
        import std.json : JSONException;
        import std.path : buildNormalizedPath;
        import std.exception : assumeUnique;

        if (rules.empty)
        {
            _empty = true;
            return;
        }

        auto jsonRule = rules.front;

        auto inputs = jsonRule["inputs"].array()
            .map!(x => Resource(buildNormalizedPath(x.str())))
            .array();

        auto outputs = jsonRule["outputs"].array()
            .map!(x => Resource(buildNormalizedPath(x.str())))
            .array();

        auto commands = jsonRule["task"].array()
            .map!(x => Command(x.array().map!(y => y.str()).array().idup))
            .array
            .assumeUnique;

        string cwd = "";

        // Optional
        try
            cwd = jsonRule["cwd"].str();
        catch(JSONException e) {}

        string display;
        try
            display = jsonRule["display"].str();
        catch(JSONException e) {}

        rule = Rule(inputs, outputs, Task(commands, cwd, display));

        rules.popFront();
    }

    inout(Rule) front() inout
    {
        return rule;
    }

    bool empty() const pure nothrow
    {
        return _empty;
    }
}

/**
 * Convenience function for constructing a Rules range.
 */
@property Rules parseRules(R)(R json)
    if (isInputRange!R)
{
    import std.json : parseJSON;
    return Rules(parseJSON(json));
}

unittest
{
    import std.algorithm : equal;

    immutable json = q{
        [
            {
                "inputs": ["foo.c", "baz.h"],
                "task": [["gcc", "-c", "foo.c", "-o", "foo.o"]],
                "display": "cc foo.c",
                "outputs": ["foo.o"]
            },
            {
                "inputs": ["bar.c", "baz.h"],
                "task": [["gcc", "-c", "bar.c", "-o", "bar.o"]],
                "outputs": ["bar.o"]
            },
            {
                "inputs": ["foo.o", "bar.o"],
                "task": [["gcc", "foo.o", "bar.o", "-o", "foobar"]],
                "outputs": ["foobar"]
            }
        ]
    };

    immutable Rule[] rules = [
        {
            inputs: [Resource("foo.c"), Resource("baz.h")],
            task: Task([Command(["gcc", "-c", "foo.c", "-o", "foo.o"])]),
            outputs: [Resource("foo.o")]
        },
        {
            inputs: [Resource("bar.c"), Resource("baz.h")],
            task: Task([Command(["gcc", "-c", "bar.c", "-o", "bar.o"])]),
            outputs: [Resource("bar.o")]
        },
        {
            inputs: [Resource("foo.o"), Resource("bar.o")],
            task: Task([Command(["gcc", "foo.o", "bar.o", "-o", "foobar"])]),
            outputs: [Resource("foobar")]
        }
    ];

    assert(parseRules(json).equal(rules));
}

unittest
{
    import std.algorithm : equal;

    immutable json = q{
        [
            {
                "inputs": ["./test/../foo.c", "./baz.h"],
                "task": [["ls", "foo.c", "baz.h"]],
                "outputs": ["this/../path/../is/../normalized"]
            }
        ]
    };

    immutable Rule[] rules = [
        {
            inputs: [Resource("foo.c"), Resource("baz.h")],
            task: Task([Command(["ls", "foo.c", "baz.h"])]),
            outputs: [Resource("normalized")]
        },
    ];

    assert(parseRules(json).equal(rules));
}
