/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graphviz;

import io.stream.types : isSink;

/**
 * Generate input suitable for GraphViz.
 */
void graphviz(Stream, BuildState)(BuildState state, Stream stream)
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
    foreach (resource; getNodes!Resource())
        stream.printfln(`        "%s";`, resource);
    stream.println("    }");

    // Style the tasks
    stream.println("    // Tasks\n"
                   "    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (task; getNodes!Task())
        stream.printfln(`        "%s";`, task);
    stream.println("    }");

    // Draw the edges from inputs to tasks
    foreach (i, edges; getEdges!Resource)
        foreach (j; edges.outgoing)
            stream.printfln(`    "%s" -> "%s";`,
                    *getNode(NodeIndex!Resource(i)),
                    *getNode(NodeIndex!Task(j)));

    // Draw the edges from tasks to outputs
    foreach (i, edges; getEdges!Task)
        foreach (j; edges.outgoing)
            stream.printfln(`    "%s" -> "%s";`,
                    *getNode(NodeIndex!Task(i)),
                    *getNode(NodeIndex!Resource(j)));
}
