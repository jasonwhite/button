/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.build;

import bb.graph;
import bb.vertex;
import bb.state;

alias BuildStateGraph = Graph!(Index!Resource, Index!Task);

/**
 * An exception relating to the build.
 */
class BuildException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Constructs the name of the build state file based on the build description
 * file name.
 */
@property string stateName(string fileName) pure nothrow
{
    import std.path : dirName, baseName, buildNormalizedPath;

    immutable string dir  = dirName(fileName);
    immutable string base = baseName(fileName);

    string prefix;

    // Prepend a '.' if there isn't one already.
    if (base.length > 0 && base[0] != '.')
        prefix = ".";

    return buildNormalizedPath(dir, prefix ~ base ~ ".state");
}

unittest
{
    assert("bb.json".stateName == ".bb.json.state");
    assert(".bb.json".stateName == ".bb.json.state");
    assert(".bb.test.json".stateName == ".bb.test.json.state");
    assert("./bb.json".stateName == ".bb.json.state");
    assert("test/bb.json".stateName == "test/.bb.json.state");
    assert("/test/.bb.json".stateName == "/test/.bb.json.state");
}

/**
 * A build description is the set of resources, tasks, and the edges between
 * them. It is constructed from a list of rules.
 */
struct BuildDescription
{
    import bb.edge;
    import bb.rule;
    import std.container.rbtree;
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

        alias VertexId(Vertex : Resource) = ResourceId;
        alias VertexId(Vertex : Task) = TaskId;
    }

    /**
     * Reads the rules from the given build description file.
     */
    this(string path)
    {
        import io.file;
        import io.range : byBlock;
        import bb.rule;

        try
        {
            auto r = File(path).byBlock!char;
            this(parseRules(&r));
        }
        catch (ErrnoException e)
        {
            throw new BuildException("Failed to open build description: " ~ e.msg);
        }
    }

    /**
     * Constructs the build description from a list of rules.
     */
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

    /**
     * Adds a rule.
     */
    void put()(auto ref Rule r)
    {
        // TODO: Throw exception if task already exists.

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

    /**
     * Adds a vertex.
     */
    void put(Vertex)(Vertex v)
        if (isVertex!Vertex)
    {
        vertices!Vertex.insert(v);
    }

    /**
     * Adds an edge.
     */
    void put(From, To)(From from, To to)
        if (isEdge!(From, To))
    {
        edges!(From, To).insert(Edge!(From, To)(from, to));
    }

    /**
     * Determines the changes between the list of vertices in the build
     * description and that in the build state.
     */
    auto diffVertices(Vertex)(BuildState state)
        if (isVertex!Vertex)
    {
        import change;
        import std.algorithm : map;

        return changes(
            state.identifiers!Vertex,
            vertices!Vertex[].map!(v => v.identifier)
            );
    }

    /**
     * Determines the changes between the list of edges in the build description
     * and that in the build state.
     */
    auto diffEdges(From, To)(BuildState state)
        if (isEdge!(From, To))
    {
        import change;
        import std.algorithm : map;

        return changes(
            state.edgeIdentifiersSorted!(VertexId!From, VertexId!To),
            edges!(From, To)[].map!(
                e => Edge!(VertexId!From, VertexId!To)(e.from.identifier, e.to.identifier)
                )
            );
    }

    /**
     * Synchronizes the build state with the build description.
     */
    void sync(BuildState state)
    {
        import change;
        import std.array : array;

        // TODO: Delete removed resources

        auto resourceDiff     = diffVertices!Resource(state).array;
        auto taskDiff         = diffVertices!Task(state).array;
        auto resourceEdgeDiff = diffEdges!(Resource, Task)(state).array;
        auto taskEdgeDiff     = diffEdges!(Task, Resource)(state).array;

        // Delete output resources that are no longer part of the build. Note
        // that the resource cannot be removed from the database yet. Edges that
        // reference it must first be removed.
        //
        // FIXME: This assumes only explicit edges are referencing this
        // resource. When implicit edges are introduced, resources should be
        // garbage collected instead.
        foreach (c; resourceDiff)
        {
            if (c.type == ChangeType.removed)
            {
                auto index = state.find(c.value);
                if (state.degreeIn(index) > 0)
                    state[index].remove();
            }
        }

        // Add the vertices and mark as pending
        foreach (c; taskDiff)
            if (c.type == ChangeType.added)
                state.addPending(state.put(Task(c.value)));

        foreach (c; resourceDiff)
            if (c.type == ChangeType.added)
                state.addPending(state.put(Resource(c.value)));

        // Add new edges and remove old edges
        foreach (c; resourceEdgeDiff)
        {
            final switch (c.type)
            {
            case ChangeType.added:
                state.put(c.value.from, c.value.to);
                break;
            case ChangeType.removed:
                state.remove(c.value.from, c.value.to);
                break;
            case ChangeType.none:
                break;
            }
        }

        foreach (c; taskEdgeDiff)
        {
            final switch (c.type)
            {
            case ChangeType.added:
                state.put(c.value.from, c.value.to);
                break;
            case ChangeType.removed:
                state.remove(c.value.from, c.value.to);
                break;
            case ChangeType.none:
                break;
            }
        }

        // Remove old vertices
        foreach (c; taskDiff)
        {
            if (c.type == ChangeType.removed)
            {
                auto id = state.find(c.value);
                state.removePending(id);
                state.remove(id);
            }
        }

        foreach (c; resourceDiff)
        {
            if (c.type == ChangeType.removed)
            {
                auto id = state.find(c.value);
                state.removePending(id);
                state.remove(id);
            }
        }
    }
}

unittest
{
    import std.algorithm : equal;
    import bb.vertex, bb.edge, bb.rule, bb.state;
    import change;

    auto state = new BuildState;

    // Resources
    state.put(Resource("foo.c"));
    state.put(Resource("bar.c"));
    state.put(Resource("baz.h"));
    state.put(Resource("foo.o"));
    state.put(Resource("baz.o"));

    // Tasks
    state.put(Task(["gcc", "-c", "foo.c", "-o", "foo.o"]));
    state.put(Task(["gcc", "-c", "bar.c", "-o", "bar.o"]));
    state.put(Task(["gcc", "foo.o", "bar.o", "-o", "foobar"]));

    Rule[] rules = [
        {
            inputs: [Resource("foo.c"), Resource("baz.h")],
            task: Task(["gcc", "-c", "foo.c", "-o", "foo.o"]),
            outputs: [Resource("foo.o")]
        },
        {
            inputs: [Resource("bar.c"), Resource("baz.h")],
            task: Task(["gcc", "-c", "bar.c", "-o", "bar.o"]),
            outputs: [Resource("bar.o")]
        },
        {
            inputs: [Resource("foo.o"), Resource("bar.o")],
            task: Task(["gcc", "foo.o", "bar.o", "-o", "barfoo"]),
            outputs: [Resource("foobar")]
        }
    ];

    auto build = BuildDescription(rules);

    immutable Change!ResourceId[] resourceResult = [
        {"bar.c",  ChangeType.none},
        {"bar.o",  ChangeType.added},
        {"baz.h",  ChangeType.none},
        {"baz.o",  ChangeType.removed},
        {"foo.c",  ChangeType.none},
        {"foo.o",  ChangeType.none},
        {"foobar", ChangeType.added},
        ];

    assert(equal(build.diffVertices!Resource(state), resourceResult));

    immutable Change!TaskId[] taskResult = [
        {["gcc", "-c", "bar.c", "-o", "bar.o"],     ChangeType.none},
        {["gcc", "-c", "foo.c", "-o", "foo.o"],     ChangeType.none},
        {["gcc", "foo.o", "bar.o", "-o", "barfoo"], ChangeType.added},
        {["gcc", "foo.o", "bar.o", "-o", "foobar"], ChangeType.removed},
        ];

    assert(equal(build.diffVertices!Task(state), taskResult));

    immutable Change!(Edge!(string, TaskId))[] taskEdgeResult = [
        {{"bar.c", ["gcc", "-c", "bar.c", "-o", "bar.o"]},     ChangeType.added},
        {{"bar.o", ["gcc", "foo.o", "bar.o", "-o", "barfoo"]}, ChangeType.added},
        {{"baz.h", ["gcc", "-c", "bar.c", "-o", "bar.o"]},     ChangeType.added},
        {{"baz.h", ["gcc", "-c", "foo.c", "-o", "foo.o"]},     ChangeType.added},
        {{"foo.c", ["gcc", "-c", "foo.c", "-o", "foo.o"]},     ChangeType.added},
        {{"foo.o", ["gcc", "foo.o", "bar.o", "-o", "barfoo"]}, ChangeType.added},
        ];

    assert(equal(build.diffEdges!(Resource, Task)(state), taskEdgeResult));
}

/**
 * Constructs a graph from the build state.
 */
@property BuildStateGraph buildGraph(BuildState state)
{
    auto g = new typeof(return)();

    // Add all vertices
    foreach (v; state.indices!Resource) g.put(v);
    foreach (v; state.indices!Task)     g.put(v);

    // Add all edges
    foreach (v; state.edges!(Resource, Task)) g.put(v.from, v.to);
    foreach (v; state.edges!(Task, Resource)) g.put(v.from, v.to);

    return g;
}

/**
 * Checks for cycles.
 *
 * Throws: BuildException exception if one or more cycles are found.
 */
void checkCycles(BuildStateGraph graph)
{
    import std.format : format;

    if (immutable cycles = graph.cycles.length)
    {
        throw new BuildException(
            "Found %d cycle(s). Use `bb graph` to see them."
            .format(cycles)
            );
    }
}

/**
 * Checks for race conditions.
 *
 * Throws: BuildException exception if one or more race conditions are found.
 */
void checkRaces(BuildStateGraph graph, BuildState state)
{
    import std.format : format;
    import std.algorithm : filter, map, joiner;
    import std.array : array;
    import std.typecons : tuple;

    auto races = graph.vertices!(Index!Resource)
                      .filter!(v => graph.degreeIn(v) > 1)
                      .map!(v => tuple(state[v], graph.degreeIn(v)))
                      .array;

    if (races.length == 0)
        return;

    if (races.length == 1)
    {
        immutable r = races[0];
        throw new BuildException(
            "Found a race condition! The resource `%s` is an output of %d tasks."
            .format(r[0], r[1])
            );
    }

    throw new BuildException(
        "Found %d race conditions:\n"
        "%s\n"
        "Use `bb graph` to see which tasks they are."
        .format(
            races.length,
            races.map!(r => " * `%s` is an output of %d tasks".format(r[0], r[1]))
                 .joiner("\n")
            )
        );
}

/**
 * Finds changes resources and adds them to the list of pending resources in the
 * database.
 */
void addChangedResources(BuildStateGraph graph, BuildState state)
{
    import std.algorithm : filter;
    import std.parallelism : parallel;

    auto resources = graph.vertices!(Index!Resource)
                          .filter!(v => graph.degreeIn(v) == 0);

    foreach (v; resources.parallel)
    {
        auto r = state[v];
        if (r.update())
        {
            state[v] = r;
            state.addPending(v);
        }
    }
}

/**
 * Traverses the graph, executing the tasks.
 *
 * This is the heart of the build system. Everything else is just support code.
 */
void build(BuildStateGraph graph, BuildState state, Index!Resource[] resources,
        Index!Task[] tasks, bool dryRun = false)
{
    import std.algorithm : filter;
    import std.array : array;

    import io;

    bool visitResource(Index!Resource v)
    {
        state.removePending(v);
        return true;
    }

    bool visitTask(Index!Task v)
    {
        // TODO: Actually run the task
        println(" > ", state[v]);

        state.removePending(v);
        return true;
    }

    graph.traverse(resources, tasks, &visitResource, &visitTask);
}

/**
 * Finds the path to the build description.
 *
 * Throws BuildException if no path is given and none could be found.
 */
string findBuildPath(string path)
{
    import std.file : isFile, FileException;
    import std.format : format;

    if (path is null)
    {
        // TODO: Search for "bb.json" in the current directory and all parent
        // directories.
        //
        // If none is found, throw BuildException.
        path = "bb.json";
    }

    try
    {
        if (!path.isFile)
            throw new BuildException(
                "Build description `%s` is not a file."
                .format(path)
                );
    }
    catch (FileException e)
    {
        throw new BuildException(
            "Build description `%s` does not exist."
            .format(path)
            );
    }

    return path;
}

/**
 * Changes the current working directory to be the parent directory of the build
 * build path. The new path to the build description is returned.
 */
string changeToBuildPath(string path)
{
    import std.file : chdir, FileException;
    import std.path : dirName, baseName;

    try
    {
        chdir(path.dirName);
    }
    catch (FileException e)
    {
        // Rethrow
        throw new BuildException(e.msg);
    }

    return path.baseName;
}

/**
 * Gets the path to the build description.
 */
string buildDescriptionPath(string path)
{
    return path.findBuildPath.changeToBuildPath;
}
