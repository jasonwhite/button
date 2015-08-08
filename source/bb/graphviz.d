/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates a GraphViz graph from the given graph.
 */
module bb.graphviz;

import io.stream.types : isSink;
import bb.graph;

/**
 * Generate input suitable for GraphViz.
 */
void graphviz(A, B, EdgeData, Stream)(auto ref Graph!(A, B, EdgeData) g, Stream stream)
    if (isSink!Stream)
{
    import io.text;
    stream.println("digraph G {");
    scope (success) stream.println("}");

    stream.println("    subgraph {\n"
                   "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
            );
    foreach (v; g.vertices!A)
        stream.printfln(`        "%s";`, v);
    stream.println("    }");

    stream.println("    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (v; g.vertices!B)
        stream.printfln(`        "%s";`, v);
    stream.println("    }");

    // Draw the edges from A -> B
    foreach (edge; g.edges!(A, B))
        stream.printfln(`    "%s" -> "%s";`, edge.from, edge.to);

    // Draw the edges from B -> A
    foreach (edge; g.edges!(B, A))
        stream.printfln(`    "%s" -> "%s";`, edge.from, edge.to);
}
