/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graphviz;

import io.stream.types : isSink;

import bb.state;

/**
 * Generate input suitable for GraphViz.
 */
void graphviz(Stream)(BuildState state, Stream stream)
    if (isSink!Stream)
{
    import io.text;
    stream.println("digraph G {");
    scope (success) stream.println("}");

    // Style the Resources
    stream.println("    // Resources\n"
                   "    subgraph {\n"
                   "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
            );
    foreach (resource; state.resources)
        stream.printfln(`        "%s";`, resource);
    stream.println("    }");

    // Style the tasks
    stream.println("    // Tasks\n"
                   "    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (task; state.tasks)
        stream.printfln(`        "%s";`, task);
    stream.println("    }");

    // Draw the edges from inputs to tasks
    foreach (edge; state.resourceEdges)
        stream.printfln(`    "%s" -> "%s";`, state[edge.from], state[edge.to]);

    // Draw the edges from tasks to outputs
    foreach (edge; state.taskEdges)
        stream.printfln(`    "%s" -> "%s";`, state[edge.from], state[edge.to]);
}
