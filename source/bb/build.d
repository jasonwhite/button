/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.build;

import std.range : ElementType;
import std.parallelism : TaskPool;

import bb.graph;
import bb.vertex, bb.edge, bb.edgedata;
import bb.state;
import bb.textcolor;
import bb.rule;
import bb.log;


alias BuildStateGraph = Graph!(
        Index!Resource,
        Index!Task,
        EdgeType,
        EdgeType,
        );

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
 * Generates a graph from a set of rules.
 */
Graph!(Resource, Task) graph(R)(auto ref R rules)
    if (is(ElementType!R : const(Rule)))
{
    auto g = new typeof(return)();

    foreach (r; rules)
    {
        g.put(r.task);

        foreach (v; r.inputs)
        {
            g.put(v);
            g.put(v, r.task);
        }

        foreach (v; r.outputs)
        {
            g.put(v);
            g.put(r.task, v);
        }
    }

    return g;
}

unittest
{
    immutable Rule[] rules = [
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
            task: Task(["gcc", "foo.o", "bar.o", "-o", "foobar"]),
            outputs: [Resource("foobar")]
        }
    ];

    auto g = graph(rules);
    assert(g.length!Task == 3);
    assert(g.length!Resource == 6);
}

/**
 * Generates the explicit subgraph from the build state.
 */
Graph!(Resource, Task) explicitGraph(BuildState state)
{
    auto g = new typeof(return)();

    // Add all tasks.
    foreach (v; state.enumerate!Task)
        g.put(v);

    // Add all explicit edges.
    // FIXME: This isn't very efficient.
    foreach (e; state.edges!(Task, Resource, EdgeType)(EdgeType.explicit))
    {
        auto r = state[e.to];
        g.put(r);
        g.put(state[e.from], r);
    }

    foreach (e; state.edges!(Resource, Task, EdgeType)(EdgeType.explicit))
    {
        auto r = state[e.from];
        g.put(r);
        g.put(r, state[e.to]);
    }

    return g;
}

/**
 * Parses the build description.
 *
 * Returns: A range of rules.
 *
 * Throws: BuildException if the build description could not be opened.
 */
Rules parseBuildDescription(string path)
{
    import io.file;
    import io.range : byBlock;
    import bb.rule;

    try
    {
        auto r = File(path).byBlock!char;
        return parseRules(&r);
    }
    catch (ErrnoException e)
    {
        throw new BuildException("Failed to open build description: " ~ e.msg);
    }
}

/**
 * Synchronizes the build state with the given set of rules.
 *
 * After the synchronization, the graph created from the set of rules will be a
 * subgraph of the graph created from the build state.
 */
void syncState(R)(R rules, BuildState state, TaskPool pool, bool dryRun = false)
    if (is(ElementType!R : const(Rule)))
{
    import util.change;
    import std.array : array;

    auto g1 = explicitGraph(state);
    auto g2 = graph(rules);

    // Analyze the build description graph. If any errors are detected, no
    // changes are made to the database.
    g2.checkCycles();
    g2.checkRaces();

    auto resourceDiff     = g1.diffVertices!Resource(g2).array;
    auto taskDiff         = g1.diffVertices!Task(g2).array;
    auto resourceEdgeDiff = g1.diffEdges!(Resource, Task)(g2);
    auto taskEdgeDiff     = g1.diffEdges!(Task, Resource)(g2);

    foreach (c; resourceDiff)
    {
        // Add the resource to the database. Note that since we only diffed
        // against the explicit subgraph of the database, we may be trying to
        // insert resources that are already in the database.
        if (c.type == ChangeType.added)
            state.add(c.value);
    }

    foreach (c; taskDiff)
    {
        // Any new tasks must be executed.
        if (c.type == ChangeType.added)
            state.addPending(state.put(c.value));
    }

    // Add new edges and remove old edges.
    foreach (c; resourceEdgeDiff)
    {
        final switch (c.type)
        {
        case ChangeType.added:
            state.put(c.value.from.identifier, c.value.to.key, EdgeType.explicit);
            break;
        case ChangeType.removed:
            state.remove(c.value.from.identifier, c.value.to.key, EdgeType.explicit);
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
            auto taskid = state.find(c.value.from.key);
            auto resid = state.find(c.value.to.identifier);
            state.addPending(taskid);
            state.put(taskid, resid, EdgeType.explicit);
            break;
        case ChangeType.removed:
            auto taskid = state.find(c.value.from.key);
            auto resid = state.find(c.value.to.identifier);

            // When an edge from a task to a resource is removed, the
            // resource should be deleted.
            if (!dryRun)
                state[resid].remove();

            state.remove(taskid, resid, EdgeType.explicit);
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
            immutable id = state.find(c.value.key);

            // Delete all outputs from this task. Note that any edges associated
            // with this task are automatically removed when the task is removed
            // from the database (because of "ON CASCADE DELETE").
            if (!dryRun)
            {
                auto outgoing = state.outgoing!(EdgeIndex!(Task, Resource))(id);
                foreach (e; pool.parallel(outgoing))
                    state[e.vertex].remove();
            }

            state.remove(id);
        }
    }

    foreach (c; resourceDiff)
    {
        // Only remove iff this resource has no outgoing implicit edges.
        // Note that, at this point, there can be no explicit edges left.
        if (c.type == ChangeType.removed)
        {
            immutable id = state.find(c.value.identifier);
            if (state.outgoing(id).empty)
                state.remove(id);
        }
    }

    // TODO: Find resources with no associated edges and remove them. These
    // resources won't cause any issues, but can slow things down if too many
    // accumulate.
}

/// Ditto
void syncState(string path, BuildState state, TaskPool pool, bool dryRun = false)
{
    syncState(parseBuildDescription(path), state, pool, dryRun);
}

/**
 * Constructs a graph from the build state. Only connected resources are added
 * to the graph.
 */
BuildStateGraph buildGraph(BuildState state, EdgeType type = EdgeType.both)
{
    auto g = new typeof(return)();

    // Add all tasks
    foreach (v; state.enumerate!(Index!Task))
        g.put(v);

    // Add all edges
    foreach (v; state.edges!(Resource, Task, EdgeType))
    {
        if (v.data & type)
        {
            g.put(v.from);
            g.put(v.from, v.to, v.data);
        }
    }

    foreach (v; state.edges!(Task, Resource, EdgeType))
    {
        if (v.data & type)
        {
            g.put(v.to);
            g.put(v.from, v.to, v.data);
        }
    }

    return g;
}

/**
 * Helper function for constructing a subgraph from the build state.
 */
private void buildGraph(Vertex, G, Visited)(BuildState state, G graph, Vertex v,
        ref Visited visited)
{
    if (v in visited)
        return;

    visited.put(v, true);

    graph.put(v);

    foreach (neighbor; state.outgoing!EdgeType(v))
    {
        buildGraph(state, graph, neighbor.vertex, visited);
        graph.put(v, neighbor.vertex, neighbor.data);
    }
}

/**
 * Constructs a subgraph from the build state starting at the given roots.
 */
BuildStateGraph buildGraph(Resources, Tasks)
        (BuildState state, Resources resources, Tasks tasks)
    if (is(ElementType!Resources : Index!Resource) &&
        is(ElementType!Tasks : Index!Task))
{
    alias G = typeof(return);
    auto g = new G();

    G.Visited!bool visited;

    foreach (v; resources)
        buildGraph(state, g, v, visited);

    foreach (v; tasks)
        buildGraph(state, g, v, visited);

    return g;
}

/**
 * Checks for cycles.
 *
 * Throws: BuildException exception if one or more cycles are found.
 */
void checkCycles(Graph!(Resource, Task) graph)
{
    import std.format : format;
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : min;

    // TODO: Construct the string instead of printing them.
    import io;

    immutable cycles = graph.cycles;

    if (!cycles.length) return;

    foreach (i, scc; cycles)
    {
        printfln("Cycle %d:", i+1);

        auto resources = scc.vertices!(Resource);
        auto tasks = scc.vertices!(Task);

        println("    ", resources[0]);
        println(" -> ", tasks[0]);

        foreach_reverse(j; 1 .. min(resources.length, tasks.length))
        {
            println(" -> ", resources[j]);
            println(" -> ", tasks[j]);
        }

        // Make the cycle obvious
        println(" -> ", resources[0]);
    }

    immutable plural = cycles.length > 1 ? "s" : "";

    throw new BuildException(
        "Found %d cycle%s. Use also `bb graph` to visualize the cycle%s."
        .format(cycles.length, plural, plural)
        );
}

/**
 * Checks for race conditions.
 *
 * Throws: BuildException exception if one or more race conditions are found.
 */
void checkRaces(Graph!(Resource, Task) graph)
{
    import std.format : format;
    import std.algorithm : filter, map, joiner;
    import std.array : array;
    import std.typecons : tuple;

    auto races = graph.vertices!(Resource)
                      .filter!(v => graph.degreeIn(v) > 1)
                      .map!(v => tuple(v, graph.degreeIn(v)))
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
 * Finds changed resources and marks them as pending in the build state.
 */
void queueChanges(BuildState state, TaskPool pool, TextColor color)
{
    import std.array : array;
    import std.algorithm.iteration : filter;
    import std.range : takeOne;
    import io.text : println;

    // FIXME: The parallel foreach fails if this is not an array.
    auto resources = state.enumerate!(Index!Resource)
        .array;

    foreach (v; pool.parallel(resources))
    {
        auto r = state[v];

        if (state.degreeIn(v) == 0)
        {
            if (r.update())
            {
                // An input changed
                state[v] = r;
                state.addPending(v);
            }
        }
        else if (r.statusKnown)
        {
            if (r.update())
            {
                // An output changed. In this case, it must be regenerated. So, we
                // add its task to the queue.
                synchronized println(
                        " - ", color.warning, "Warning", color.reset,
                        ": Output file `", color.purple, r, color.reset,
                        "` was changed externally and will be regenerated.");

                // A resource should only ever have one incoming edge. If that
                // is not the case, then we've got bigger problems.
                auto incoming = state
                    .incoming!(NeighborIndex!(Index!Resource))(v)
                    .takeOne;
                assert(incoming.length == 1,
                        "Output resource has does not have 1 incoming edge!");
                state.addPending(incoming[0].vertex);
            }
        }
    }
}

/**
 * Syncs the build state with implicit dependencies.
 */
void syncStateImplicit(BuildState state, Index!Task v,
        immutable(ubyte)[] inputs, immutable(ubyte)[] outputs)
{
    import std.algorithm.iteration : splitter, uniq, filter, map;
    import std.array : array;
    import std.algorithm.sorting : sort;
    import std.format : format;
    import util.change;
    import bb.deps;

    auto inputDiff = changes(
            state.incoming!Resource(v, EdgeType.implicit).array.sort(),
            inputs.deps.array.sort().uniq
            );

    auto outputDiff = changes(
            state.outgoing!Resource(v, EdgeType.implicit).array.sort(),
            outputs.deps.array.sort().uniq
            );

    foreach (c; inputDiff)
    {
        if (c.type == ChangeType.added)
        {
            auto r = c.value;

            // A new implicit input. If the resource is *not* an output
            // resource, then we are fine. Otherwise, it is an error because we
            // are potentially changing the build order with this new edge.
            auto id = state.find(r.path);
            if (id == Index!Resource.Invalid)
            {
                // Resource doesn't exist. It is impossible to change the build
                // order by adding it.
                r.update();
                state.put(state.put(r), v, EdgeType.implicit);
            }
            else if (state.degreeIn(id) == 0 ||
                     state.edgeExists(id, v, EdgeType.explicit))
            {
                // Resource exists, but no task is outputting to it or an
                // explicit edge already exists. In these situations it is
                // impossible to change the build order by adding an edge to it.
                state.put(id, v, EdgeType.implicit);
            }
            else
            {
                throw new TaskError(
                    "Implicit task input '%s' would change the build order." ~
                    " It must be explicitly added to the build description."
                    .format(r)
                    );
            }
        }
        else if (c.type == ChangeType.removed)
        {
            // Build state has edges that weren't discovered implicitly. These
            // can either be explicit edges that weren't found, removed implicit
            // edges, or both.
            auto id = state.find(c.value.path);
            assert(id != Index!Resource.Invalid);
            state.remove(id, v, EdgeType.implicit);
        }
    }

    foreach (c; outputDiff)
    {
        if (c.type == ChangeType.added)
        {
            auto r = c.value;

            // A new implicit output. The resource must either not exist or be a
            // dangling resource awaiting garbage collection. Otherwise, it is
            // an error.
            auto id = state.find(r.path);
            if (id == Index!Resource.Invalid)
            {
                // Resource doesn't exist. It is impossible to change the
                // builder order by adding it.
                r.update();
                state.put(v, state.put(r), EdgeType.implicit);
            }
            else if ((state.degreeIn(id) == 0 && state.degreeOut(id) == 0) ||
                     state.edgeExists(v, id, EdgeType.explicit))
            {
                // Resource exists, but it is neither an input nor an output
                // (i.e., an orphan that hasn't been garbage collected), or an
                // explicit edge already exists. In these situations it is
                // impossible to change the build order by adding an implicit
                // edge.
                state.put(v, id, EdgeType.implicit);
            }
            else
            {
                throw new TaskError(
                    "Implicit task output '%s' would change the build order." ~
                    " It must be explicitly added to the build description."
                    .format(r)
                    );
            }
        }
        else if (c.type == ChangeType.removed)
        {
            // Build state has edges that weren't discovered implicitly. These
            // can be either explicit edges that weren't found or removed
            // implicit edges. We only care about the latter case here.
            auto id = state.find(c.value.path);
            assert(id != Index!Resource.Invalid);

            state[id].remove();
            state.remove(v, id, EdgeType.implicit);
            state.remove(id);
        }
    }
}

struct VisitorContext
{
    BuildState state;

    bool dryRun;

    bool verbose;

    TextColor color;

    Logger logger;
}

/**
 * Called when a resource vertex is visited.
 *
 * Returns true if we should continue traversing the graph.
 */
bool visitResource(VisitorContext* context, Index!Resource v, size_t degreeIn,
        size_t degreeChanged)
{
    scope (success)
        context.state.removePending(v);

    // Do not consider ourselves changed if none of our dependencies changed.
    if (degreeChanged == 0)
        return false;

    // Leaf resources are already checked for changes when discovering roots
    // from which to construct the subgraph. Thus, there is no need to do it
    // here as well.
    if (degreeIn == 0)
        return true;

    // This is an output resource. Its parent task may have changed it. Thus,
    // check for any change.
    auto r = context.state[v];
    if (r.update())
    {
        context.state[v] = r;
        return true;
    }

    return false;
}

/**
 * Called when a task vertex is visited.
 *
 * Returns true if we should continue traversing the graph.
 */
bool visitTask(VisitorContext* context, Index!Task v, size_t degreeIn,
        size_t degreeChanged)
{
    import io;
    import std.datetime : StopWatch, AutoStart;
    import core.time : TickDuration;
    import std.format : format;

    immutable pending = context.state.isPending(v);

    if (degreeChanged == 0 && !pending)
        return false;

    immutable color = context.color;

    // We add this as pending if it isn't already just in case the build is
    // interrupted or if it fails.
    if (!pending) context.state.addPending(v);

    auto task = context.state[v];

    auto taskLogger = context.logger.taskStarted(v, task, context.dryRun);

    // Assume the command would succeed in a dryrun
    if (context.dryRun)
    {
        taskLogger.succeeded(TickDuration.zero);
        return true;
    }

    auto result = task.execute(taskLogger);

    try
    {
        if (result.status != 0)
            throw new TaskError(
                    "Process exited with code %d".format(result.status)
                    );

        synchronized (context.state)
            syncStateImplicit(context.state, v, result.inputs, result.outputs);
    }
    catch (TaskError e)
    {
        taskLogger.failed(result.duration, e);
        throw e;
    }

    // Only remove this from the set of pending tasks if it succeeds completely.
    // If it fails, it should get executed again on the next run such that other
    // tasks that depend on this (if any) can be executed.
    context.state.removePending(v);

    taskLogger.succeeded(result.duration);

    return true;
}

/**
 * Traverses the graph, executing the tasks.
 *
 * This is the heart of the build system. Everything else is just support code.
 */
void build(BuildStateGraph graph, BuildState state, TaskPool pool,
        bool dryRun, bool verbose, TextColor color, Logger logger)
{
    import std.algorithm : filter, map;
    import std.array : array;

    auto ctx = VisitorContext(state, dryRun, verbose, color, logger);

    graph.traverse!(visitResource, visitTask)(&ctx, pool);
}

/**
 * Deletes all outputs from the file system.
 */
void clean(BuildState state)
{
    import io.text, io.file.stdio;

    foreach (id; state.enumerate!(Index!Resource))
    {
        if (state.degreeIn(id) > 0)
        {
            auto r = state[id];
            println("Deleting `", r, "`");
            r.remove();
        }
    }
}

/**
 * If this build system is running under itself, send back all of its
 * inputs and outputs.
 */
void publishResources(BuildState state)
{
    import std.process;
    import std.conv : to;
    import io.file.stream;
    import bb.deps;

    auto inputsHandle  = environment.get("BB_INPUTS");
    auto outputsHandle = environment.get("BB_OUTPUTS");

    if (inputsHandle is null || outputsHandle is null)
        return;

    version (Posix)
    {
        auto inputs  = File(inputsHandle.to!int);
        auto outputs = File(outputsHandle.to!int);

        foreach (v; state.enumerate!(Index!Resource))
        {
            immutable degreeIn  = state.degreeIn(v);
            immutable degreeOut = state.degreeOut(v);

            if (degreeIn == 0 && degreeOut == 0)
                continue; // Dangling resource

            auto r = state[v];

            auto dep = Dependency(
                    cast(ulong)r.lastModified.stdTime,
                    r.checksum,
                    r.path.length.to!uint
                    );

            if (degreeIn == 0)
            {
                inputs.write((&dep)[0 .. 1]);
                inputs.write(r.path);
            }
            else
            {
                outputs.write((&dep)[0 .. 1]);
                outputs.write(r.path);
            }
        }
    }
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
 * description path. The new path to the build description is returned.
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
