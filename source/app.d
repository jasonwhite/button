import io;

struct Rule
{
    string[] inputs;
    string[] outputs;
    string task;
    string description;
}

struct Rules
{
    import std.json;

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

        if (rules.empty)
        {
            _empty = true;
            return;
        }

        auto jsonRule = rules.front;

        auto inputs = jsonRule["inputs"].array().map!(x => x.str()).array();
        auto outputs = jsonRule["outputs"].array().map!(x => x.str()).array();
        auto task = jsonRule["task"].str();

        // Optional description
        string description = null;

        try
        {
            description = jsonRule["description"].str();
        }
        catch (JSONException e)
        {
            // Ignore. Description is optional.
        }

        rule = Rule(inputs, outputs, task, description);

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
Rules parseRules(Stream)(Stream stream)
    if (isSource!Stream)
{
    import std.json : parseJSON;
    return Rules(stream.byBlock!char.parseJSON()["rules"]);
}

/// Ditto
Rules parseRules(string fileName)
{
    return parseRules(File(fileName, FileFlags.readExisting));
}

int main(string[] args)
{
    import std.json : JSONException;

    try
    {
        foreach (const ref rule; stdin.parseRules())
        {
            println("Inputs:      ", rule.inputs);
            println("Outputs:     ", rule.outputs);
            println("Task:        ", rule.task);
            println("Description: ", rule.description);
            println();
        }
    }
    catch (JSONException e)
    {
        stderr.println("Error parsing rules from JSON (", e.msg, ")");
        return 1;
    }

    // TODO: Create graph from rules.

    return 0;
}
