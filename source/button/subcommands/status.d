/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Displays status about the build.
 */
module button.subcommands.status;

import button.subcommands.parsing;

import std.getopt;
import std.range : empty;
import std.array : array;
import std.algorithm : sort, map, filter;

import io.text,
       io.file;

import button.task;
import button.resource;
import button.state;
import button.build;
import button.textcolor;

int statusCommand(StatusOptions opts, GlobalOptions globalOpts)
{
    import std.parallelism : TaskPool, totalCPUs;

    if (opts.threads == 0)
        opts.threads = totalCPUs;

    auto pool = new TaskPool(opts.threads - 1);
    scope (exit) pool.finish(true);

    immutable color = TextColor(colorOutput(opts.color));

    try
    {
        string path = buildDescriptionPath(opts.path);
        auto state = new BuildState(path.stateName);

        state.begin();
        scope (exit) state.rollback();

        if (!opts.cached)
        {
            path.syncState(state, pool);

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
    import util.change;

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
    auto resources = state.enumerate!Resource
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
