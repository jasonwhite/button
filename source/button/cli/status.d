/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Displays status about the build.
 */
module button.cli.status;

import button.cli.options : StatusOptions, GlobalOptions;

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
import button.exceptions;

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
            path.syncState(state, pool);

        printfln("%d resources and %d tasks total",
                state.length!Resource,
                state.length!Task);

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

void displayPendingResources(BuildState state, TextColor color)
{
    auto resources = state.enumerate!Resource
                          .filter!(v => v.update())
                          .array
                          .sort();

    if (resources.empty)
    {
        println("No resources have been modified.");
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
    auto tasks = state.pending!Task.array;

    if (tasks.empty)
    {
        println("No tasks are pending.");
    }
    else
    {
        printfln("%d pending task(s):\n", tasks.length);

        foreach (v; tasks)
            println("    ", color.blue, state[v].toPrettyString, color.reset);

        println();
    }
}
