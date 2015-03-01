import io;
import bb.rule;

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
            addRule(rule);
    }

    /**
     * Adds a single rule to the graph.
     */
    void addRule()(auto ref Rule rule)
    {
        // TODO
        println("Inputs:      ", rule.inputs);
        println("Outputs:     ", rule.outputs);
        println("Task:        ", rule.task);
        println("Description: ", rule.description);
        println();
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
