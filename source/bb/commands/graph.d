/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.commands.graph;

import std.array : array;
import std.algorithm.iteration : filter;
import std.getopt;

import io.text,
       io.file;

import io.stream.types : isSink;

import bb.vertex,
       bb.graph,
       bb.state,
       bb.build;


private struct Options
{
    // Path to the build description
    string path;

    // Only display the minimal subgraph?
    bool changes;

    // Display the graph stored in the database.
    bool cached;

    enum Edges
    {
        explicit = 1 << 0,
        implicit = 1 << 1,
        both = explicit | implicit,
    }

    // What types of edges to show
    Edges edges = Edges.both;
}

immutable usage = q"EOS
Usage: bb graph [-f FILE] [--changes] [--edges {explicit,implicit,both}]
EOS";

int graph(string[] args)
{
    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
        "changes|c",
            "Only display the subgraph that will be traversed on an update",
            &options.changes,
        "edges|e",
            "Type of edges to show",
            &options.edges,
        "cached",
            "Display the cached graph from the previous build.",
            &options.cached,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInfo.options);
        return 0;
    }

    try
    {
        string path = buildDescriptionPath(options.path);
        auto build = BuildDescription(path);

        auto state = new BuildState(path.stateName);

        state.begin();
        scope (exit) state.rollback();

        if (!options.cached)
            build.sync(state);

        auto graph = state.buildGraph;

        if (options.changes)
        {
            // Add changed resources to the build state.
            if (!options.cached)
                graph.addChangedResources(state);

            // Construct the minimal subgraph based on pending vertices
            auto resourceRoots = state.pending!Resource
                .filter!(v => state.degreeIn(v) == 0)
                .array;

            auto taskRoots = state.pending!Task
                .filter!(v => state.degreeIn(v) == 0)
                .array;

            auto subgraph = graph.subgraph(resourceRoots, taskRoots);
            subgraph.graphviz(state, stdout);
        }
        else
        {
            graph.graphviz(state, stdout);
        }
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}

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
