/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.commands.graph;

import bb.commands.parsing;

import std.array : array;
import std.algorithm.iteration : filter;
import std.getopt;

import io.text,
       io.file;

import io.stream.types : isSink;

import bb.vertex,
       bb.edgedata,
       bb.graph,
       bb.state,
       bb.build;


int graphCommand(Options!"graph" opts, GlobalOptions globalOpts)
{
    try
    {
        string path = buildDescriptionPath(opts.path);

        auto state = new BuildState(path.stateName);

        state.begin();
        scope (exit) state.rollback();

        if (!opts.cached)
        {
            path.syncState(state, true);
        }

        auto graph = state.buildGraph;

        if (opts.changes)
        {
            // Construct the minimal subgraph based on pending vertices
            auto resourceRoots = state.enumerate!(Index!Resource)
                .filter!(v => state.degreeIn(v) == 0 && state[v].update())
                .array;

            auto taskRoots = state.pending!Task
                .filter!(v => state.degreeIn(v) == 0)
                .array;

            auto subgraph = graph.subgraph(resourceRoots, taskRoots);
            subgraph.graphviz(state, stdout, opts.verbose == OptionFlag.yes);
        }
        else
        {
            graph.graphviz(state, stdout, opts.verbose == OptionFlag.yes);
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
        BuildStateGraph graph,
        BuildState state,
        Stream stream,
        bool verbose
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
    foreach (id; graph.vertices!A)
    {
        immutable v = state[id];
        immutable name = verbose ? v.toString : v.shortString;
        stream.printfln(`        "r:%s" [label="%s", tooltip="%s"];`, id, name, v);
    }
    stream.println("    }");

    stream.println("    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (id; graph.vertices!B)
    {
        immutable v = state[id];
        immutable name = verbose ? v.toString : v.shortString;
        stream.printfln(`        "t:%s" [label="%s", tooltip="%s"];`, id, name, v);
    }
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

    immutable styles = ["solid", "dashed"];

    // Edges
    foreach (edge; graph.edges!(A, B))
    {
        stream.printfln(`    "r:%s" -> "t:%s" [style=%s];`,
                edge.from, edge.to, styles[edge.data]);
    }

    foreach (edge; graph.edges!(B, A))
    {
        stream.printfln(`    "t:%s" -> "r:%s" [style=%s];`,
                edge.from, edge.to, styles[edge.data]);
    }
}

/// Ditto
void graphviz(Stream)(Graph!(Resource, Task) graph, Stream stream)
    if (isSink!Stream)
{
    import io.text;
    import std.range : enumerate;

    alias A = Resource;
    alias B = Task;

    stream.println("digraph G {");
    scope (success) stream.println("}");

    // Vertices
    stream.println("    subgraph {\n"
                   "        node [shape=ellipse, fillcolor=lightskyblue2, style=filled];"
            );
    foreach (v; graph.vertices!Resource)
    {
        stream.printfln(`        "r:%s"`, v);
    }
    stream.println("    }");

    stream.println("    subgraph {\n"
                   "        node [shape=box, fillcolor=gray91, style=filled];"
            );
    foreach (v; graph.vertices!Task)
    {
        stream.printfln(`        "t:%s"`, v);
    }
    stream.println("    }");

    // Cluster cycles, if any
    foreach (i, scc; enumerate(graph.cycles))
    {
        stream.printfln("    subgraph cluster_%d {", i++);

        foreach (v; scc.vertices!Resource)
            stream.printfln(`        "r:%s";`, v);

        foreach (v; scc.vertices!Task)
            stream.printfln(`        "t:%s";`, v);

        stream.println("    }");
    }

    // Edges
    // TODO: Style as dashed edge if implicit edge
    foreach (edge; graph.edges!(Resource, Task))
        stream.printfln(`    "r:%s" -> "t:%s";`, edge.from, edge.to);

    foreach (edge; graph.edges!(Task, Resource))
        stream.printfln(`    "t:%s" -> "r:%s";`, edge.from, edge.to);
}
