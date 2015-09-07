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
    import bb.state;
    import std.range.primitives : ElementType;

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

    this(R)(auto ref R rules)
        if (is(ElementType!R : const(Rule)))
    {
        _resources = redBlackTree!(Resource)();
        _tasks     = redBlackTree!(Task)();
        _edgesRT   = redBlackTree!(Edge!(Resource, Task))();
        _edgesTR   = redBlackTree!(Edge!(Task, Resource))();

        foreach (r; rules)
            put(r);
    }

    void put()(auto ref Rule r)
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

    auto diffVertices(Vertex)(BuildState state)
        if (isVertex!Vertex)
    {
        import change;
        import std.algorithm : map;

        return changes(vertices!Vertex[].map!(v => v.identifier),
                state.identifiers!Vertex);
    }
}

unittest
{
    import std.algorithm : equal;
    import bb.rule, bb.state;
    import bb.vertex;
    import change;

    Rule[] rules = [
        {
            inputs: [Resource("foo.c"), Resource("baz.h")],
            task: Task(["gcc", "-c", "foo.c", "-o", "foo.o"], "cc foo.c"),
            outputs: [Resource("foo.o")]
        },
        {
            inputs: [Resource("bar.c"), Resource("baz.h")],
            task: Task(["gcc", "-c", "bar.c", "-o", "bar.o"]),
            outputs: [Resource("bar.o")]
        },
        {
            inputs: [Resource("foo.o"), Resource("bar.o")],
            task: Task(["gcc", "foo.o", "bar.o", "-o", "foobar"]),
            outputs: [Resource("foobar")]
        }
    ];

    auto build = BuildDescription(rules);

    auto state = new BuildState;
    state.put(Resource("foo.c"));
    state.put(Resource("bar.c"));
    state.put(Resource("baz.h"));
    state.put(Resource("foo.o"));
    state.put(Resource("baz.o"));

    immutable Change!ResourceId[] resourceResult = [
        {"bar.c",  ChangeType.none},
        {"bar.o",  ChangeType.removed},
        {"baz.h",  ChangeType.none},
        {"baz.o",  ChangeType.added},
        {"foo.c",  ChangeType.none},
        {"foo.o",  ChangeType.none},
        {"foobar", ChangeType.removed},
        ];

    assert(equal(build.diffVertices!Resource(state), resourceResult));

    immutable Change!TaskId[] taskResult = [
        {["gcc", "-c", "bar.c", "-o", "bar.o"],     ChangeType.removed},
        {["gcc", "-c", "foo.c", "-o", "foo.o"],     ChangeType.removed},
        {["gcc", "foo.o", "bar.o", "-o", "foobar"], ChangeType.removed},
        ];

    assert(equal(build.diffVertices!Task(state), taskResult));
}
