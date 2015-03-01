/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.taskgraph;

import bb.rule;

import io.stream.types : isSink;

alias Resource = string;
alias Task = string;

/**
 * Bipartite task graph.
 *
 * Resource nodes have edges to tasks. Task nodes have edges to resources.
 */
struct TaskGraph
{
    // Resource -> Task[]
    Task[][Resource] resources;

    // Task -> Resource[]
    Resource[][Task] tasks;

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
        // Add inputs to graph
        foreach (input; rule.inputs)
        {
            if (auto tasks = input in resources)
                (*tasks) ~= rule.task;
            else
                resources[input] = [rule.task];
        }

        // Add task and its outputs to graph
        if (auto resources = rule.task in tasks)
            (*resources) ~= rule.outputs; // Merge it
        else
            tasks[rule.task] = rule.outputs;

        // Add outputs to graph
        foreach (output; rule.outputs)
        {
            if (output !in resources)
                resources[output] = [];
        }
    }

    /**
     * Generate a graph for GraphViz
     */
    void display(Stream)(Stream stream)
        if (isSink!Stream)
    {
        import io;
        stream.println("digraph G {");
        scope (success) stream.println("}");

        // Style the tasks
        stream.println("    // Tasks\n"
                       "    subgraph {\n"
                       "        node [shape=box, fillcolor=gray91, style=filled];"
                );
        foreach (task; tasks.byKey)
            stream.printfln(`        "%s";`, task);
        stream.println("    }");

        // Style the Resources
        stream.println("    // Resources\n"
                       "    subgraph {\n"
                       "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
                );
        foreach (resource; resources.byKey)
            stream.printfln(`        "%s";`, resource);
        stream.println("    }");

        // Draw the edges from inputs to tasks
        foreach (resource, tasks; resources)
            foreach (task; tasks)
                stream.printfln(`    "%s" -> "%s";`, resource, task);

        // Draw the edges from tasks to outputs
        foreach (task, resources; tasks)
            foreach (resource; resources)
                stream.printfln(`    "%s" -> "%s";`, task, resource);
    }
}
