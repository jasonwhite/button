/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Displays status about the build.
 */
module bb.commands.status;

import std.getopt;
import std.range : empty;
import std.array : array;
import std.algorithm : sort, map, filter;

import io.text,
       io.file;

import bb.vertex,
       bb.state,
       bb.build;

private struct Options
{
    // Path to the build description
    string path;

    // Display the cached list of changes.
    bool cached;
}

immutable usage = q"EOS
Usage: bb status [-f FILE] [--cached]
EOS";

int status(string[] args)
{
    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
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
        auto state = new BuildState(path.stateName);

        state.begin();
        scope (exit) state.rollback();

        if (!options.cached)
        {
            auto build = BuildDescription(path);
            build.sync(state);

            displayResourceDiff(build, state);
        }

        printfln("%d total resources", state.length!Resource);
        printfln("%d total tasks", state.length!Task);

        displayPendingResources(state);
        displayPendingTasks(state);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}

void displayResourceDiff(ref BuildDescription build, BuildState state)
{
    import change;

    // TODO: Colorize this output.

    auto resourceDiff = build.diffVertices!Resource(state)
                             .filter!(c => c.type != ChangeType.none);

    if (resourceDiff.empty)
        return;

    println("Resource changes:\n");

    foreach (c; resourceDiff)
    {
        final switch (c.type)
        {
        case ChangeType.added:
            println("    new:     ", Resource(c.value));
            break;
        case ChangeType.removed:
            println("    removed: ", Resource(c.value));
            break;
        case ChangeType.none:
            break;
        }
    }

    println();
}

void displayPendingResources(BuildState state)
{
    auto resources = state.vertices!Resource
                          .filter!(v => v.update())
                          .array
                          .sort();

    if (resources.empty)
    {
        println("No modified resources.");
    }
    else
    {
        printfln("%d modified resource(s):\n", resources.length);

        foreach (v; resources)
            println("    ", v);

        println();
    }
}

void displayPendingTasks(BuildState state)
{
    auto tasks = state.pending!Task;

    if (tasks.empty)
    {
        println("No pending tasks.");
    }
    else
    {
        println("Pending tasks:\n");

        foreach (v; tasks)
            println("    ", state[v]);

        println();
    }
}
