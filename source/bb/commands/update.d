/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import bb.graph;
import bb.build;

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    import io.text, io.file, io.buffer;
    import io.range : byBlock;
    import bb.state, bb.rule;
    import std.array : array;

    auto buildDesc = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        stderr.println(":: Loading build description...");

        auto r = File(buildDesc).byBlock!char;
        auto g = graph(parseRules(&r));

        auto state = new BuildState(buildDesc.stateName);

        // TODO: Diff build description with database
        stderr.println(":: Checking for build description changes...");
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    stderr.println(":: Updating...");

    // TODO: Build subgraph and update.

    return 0;
}

/**
 *
 */
struct BuildDescription
{
    import bb.vertex, bb.edge;
    import bb.rule;
    import std.container.rbtree;

    private
    {
        // Vertices
        RedBlackTree!Resource _resources;
        RedBlackTree!Task     _tasks;

        // Edges
        RedBlackTree!(Edge!(Resource, Task)) _edgesRT;
        RedBlackTree!(Edge!(Task, Resource)) _edgesTR;

        alias vertices(Vertex : Resource) = _resources;
        alias vertices(Vertex : Task) = _tasks;
        alias edges(From : Resource, To : Task) = _edgesRT;
        alias edges(From : Task, To : Resource) = _edgesTR;

        enum isVertex(Vertex) = is(Vertex : Resource) || is(Vertex : Task);
        enum isEdge(From, To) = isVertex!From && isVertex!To;
    }

    this(Rules rules)
    {
        foreach (r; rules)
            put(r);
    }

    void put(ref Rule r)
    {
        _tasks.insert(r.task);

        foreach (v; r.inputs)
        {
            put(v);
            put(v, r.task);
        }

        foreach (v; r.outputs)
        {
            put(v);
            put(r.task, v);
        }
    }

    void put(Vertex)(Vertex v)
        if (isVertex!Vertex)
    {
        vertices!Vertex.insert(v);
    }

    void put(From, To)(From from, To to)
        if (isEdge!(From, To))
    {
        edges!(From, To).insert(Edge!(From, To)(from, to));
    }
}
