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
       bb.build,
       bb.textcolor;

private struct Options
{
    // Path to the build description
    string path;

    // Display the cached list of changes.
    bool cached;

    // When to colorize the output.
    string color = "auto";
}

immutable usage = q"EOS
Usage: bb status [-f FILE] [--cached]
EOS";

int statusCommand(string[] args)
{
    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
        "cached",
            "Display the cached graph from the previous build.",
            &options.cached,
        "color",
            "When to colorize the output.",
            &options.color,
    );

    immutable color = TextColor(colorOutput(options.color));

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
            path.syncState(state);

            //displayResourceDiff(build, state, color);
        }

        printfln("%d total resources", state.length!Resource);
        printfln("%d total tasks", state.length!Task);

        displayPendingResources(state, color);
        displayPendingTasks(state, color);
    }
    catch (BuildException e)
    {
        stderr.println(":: Error: ", e.msg);
        return 1;
    }

    return 0;
}

version (none) void displayResourceDiff(ref BuildDescription build, BuildState state,
        TextColor color)
{
    import change;

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
            println("    new:     ", color.green, Resource(c.value), color.reset);
            break;
        case ChangeType.removed:
            println("    removed: ", color.red, Resource(c.value), color.reset);
            break;
        case ChangeType.none:
            break;
        }
    }

    println();
}

void displayPendingResources(BuildState state, TextColor color)
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
            println("    ", color.blue, v, color.reset);

        println();
    }
}

void displayPendingTasks(BuildState state, TextColor color)
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
            println("    ", color.blue, state[v], color.reset);

        println();
    }
}
