/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 *
 * Description:
 * Parses rules.
 */
import io;
import bb.rule;
import bb.taskgraph;
import bb.resource, bb.task;

int main(string[] args)
{
    import std.json : JSONException;

    string command = "update";

    if (args.length > 1)
        command = args[1];

    try
    {
        TaskGraph graph;
        graph.addRules(stdin.parseRules());

        if (command == "show")
        {
            // TODO: Create argument to output to a file.
            stderr.println(" :: Generating input for GraphViz...");
            graph.show(stdout);
        }
        else if (command == "update")
        {
            // TODO: Monitor for changes to resources.
            // TODO: Use database to check for changes to tasks.
            auto changedResources = [
                    graph.getIndex!Resource("foo.c"),
                ];
            auto subgraph = graph.subgraph(changedResources, []);
            graph.update(changedResources, []);
        }
    }
    catch (JSONException e)
    {
        stderr.println("Error parsing rules from JSON (", e.msg, ")");
        return 1;
    }

    return 0;
}
