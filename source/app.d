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

/**
 * Bipartite task graph.
 *
 * Resource nodes have edges to tasks. Task nodes have edges to resources.
 */
struct TaskGraph
{
    string[string] resources;
    string[string] tasks;

    /**
     * Adds a range of rules to the graph.
     */
    void addRules()(auto ref Rules rules)
    {
        foreach (rule; rules)
        {
            // TODO
            println("Inputs:      ", rule.inputs);
            println("Outputs:     ", rule.outputs);
            println("Task:        ", rule.task);
            println("Description: ", rule.description);
            println();
        }
    }
}

/**
 * Creates the bipartite task graph from the given range of rules.
 */

int main(string[] args)
{
    import std.json : JSONException;

    try
    {
        TaskGraph graph;
        graph.addRules(stdin.parseRules());
    }
    catch (JSONException e)
    {
        stderr.println("Error parsing rules from JSON (", e.msg, ")");
        return 1;
    }

    return 0;
}
