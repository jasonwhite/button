/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Parses rules.
 */
module bb.rule;

import std.range : isInputRange;

struct Rule
{
    string[] inputs, outputs;
    immutable(string)[] task;
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

        if (rules.empty)
        {
            _empty = true;
            return;
        }

        auto jsonRule = rules.front;

        auto inputs = jsonRule["inputs"].array()
            .map!(x => buildNormalizedPath(x.str()))
            .array();

        auto outputs = jsonRule["outputs"].array()
            .map!(x => buildNormalizedPath(x.str()))
            .array();

        auto task = jsonRule["task"].array()
            .map!(x => x.str())
            .array()
            .idup;

        rule = Rule(inputs, outputs, task);

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
Rules parseRules(R)(R json)
    if (isInputRange!R)
{
    import std.json : parseJSON;
    return Rules(parseJSON(json)["rules"]);
}

unittest
{
    import std.algorithm : equal;

    //parseRules();
}
