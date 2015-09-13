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

import bb.vertex,
       bb.edge,
       bb.state,
       bb.graph;

/**
 * Generates input suitable for GraphViz.
 */
void graphviz(Stream)(
        Graph!(Index!Resource, Index!Task) graph,
        BuildState state,
        Stream stream
        )
    if (isSink!Stream)
{
    import io.text;
    import std.range : enumerate;

    alias A = Index!Resource;
    alias B = Index!Task;

    stream.println("digraph G {");
    scope (success) stream.println("}");

    // Vertices
    stream.println("    subgraph {\n"
                   "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
            );
    foreach (v; graph.vertices!A)
        stream.printfln(`        "r:%s" [label="%s"];`, v, state[v]);
    stream.println("    }");

    stream.println("    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (v; graph.vertices!B)
        stream.printfln(`        "t:%s" [label="%s"];`, v, state[v]);
    stream.println("    }");

    // Cluster cycles, if any
    foreach (i, scc; enumerate(graph.cycles))
    {
        stream.printfln("    subgraph cluster_%d {", i++);

        foreach (v; scc.vertices!A)
            stream.printfln(`        "r:%s";`, v);

        foreach (v; scc.vertices!B)
            stream.printfln(`        "t:%s";`, v);

        stream.println("    }");
    }

    // Edges
    // TODO: Style as dashed edge if implicit edge
    foreach (edge; graph.edges!(A, B))
        stream.printfln(`    "r:%s" -> "t:%s";`, edge.from, edge.to);

    foreach (edge; graph.edges!(B, A))
        stream.printfln(`    "t:%s" -> "r:%s";`, edge.from, edge.to);
}
