import std.stdio;
import std.json;
import std.file;
import std.array;
import std.algorithm;

struct Rule
{
    string[] inputs;
    string[] outputs;
    string task;
    string description;
}

struct Rules
{
    // Current rule
    private Rule _rule;

    this(string fileName)
    {
        // Prime the cannon
        popFront();
    }

    void popFront()
    {
    }

    inout(Rule) front() inout
    {
        return _rule;
    }

    bool empty() const pure nothrow
    {
        return true;
    }
}

/**
 * Parses rules from the file with the given name.
 */
Rules rules(string fileName)
{
    return Rules(fileName);
}


Rule[] parseRules(string fileName)
{
    auto json = parseJSON(readText(fileName));

    auto rules = appender!(Rule[])();

    foreach (rule; json["rules"].array())
    {
        auto inputs = rule["inputs"].array().map!(x => x.str()).array();
        auto outputs = rule["outputs"].array().map!(x => x.str()).array();
        auto task = rule["task"].str();

        // Optional description
        string description = null;

        try
        {
            description = rule["description"].str();
        }
        catch (JSONException e)
        {
            // Ignore. Description is optional.
        }

        rules.put(Rule(inputs, outputs, task, description));

        writeln("Inputs: ", inputs);
        writeln("Outputs: ", outputs);
        writeln("Task: ", task);
        writeln("Description: ", description);
        writeln();
    }

    return rules.data;
}

int main(string[] args)
{
    if (args.length < 2)
    {
        stderr.writefln("Usage: %s FILE [FILE...]", args[0]);
        return 1;
    }

    Rule[] rules;

    try
    {
        rules = parseRules(args[1]);
    }
    catch (JSONException e)
    {
        stderr.writeln("Error parsing rules from JSON (", e.msg, ")");
        return 1;
    }

    // TODO: Create graph from rules.

    return 0;
}
