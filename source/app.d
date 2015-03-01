import io;
import bb.rule;
import bb.taskgraph;


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
