/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Visualizing the build.
 */
module bb.visualize;

import io.stream.types : isSink;

import bb.vertex;
import bb.state;

/**
 * Generates input suitable for GraphViz.
 */
void graphviz(Stream)(
        BuildState state,
        Stream stream
        )
    if (isSink!Stream)
{
    import io.text;

    alias A = Index!Resource;
    alias B = Index!Task;

    stream.println("digraph G {");
    scope (success) stream.println("}");

    // Vertices
    stream.println("    subgraph {\n"
                   "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
            );
    foreach (v; state.indices!Resource)
        stream.printfln(`        "r:%s" [label="%s"];`, v, state[v]);
    stream.println("    }");

    stream.println("    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (v; state.indices!Task)
        stream.printfln(`        "t:%s" [label="%s"];`, v, state[v]);
    stream.println("    }");

    // Edges
    foreach (edge; state.edges!(Resource, Task))
        stream.printfln(`    "r:%s" -> "t:%s";`, edge.from, edge.to);

    foreach (edge; state.edges!(Task, Resource))
        stream.printfln(`    "t:%s" -> "r:%s";`, edge.from, edge.to);
}
