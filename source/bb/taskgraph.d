/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.taskgraph;

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
        import io.text;

        // TODO
        println("Inputs:      ", rule.inputs);
        println("Outputs:     ", rule.outputs);
        println("Task:        ", rule.task);
        println("Description: ", rule.description);
        println();
    }
}
