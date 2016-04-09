/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles the 'update' or 'build' command.
 */
module bb.commands.update;

import bb.commands.parsing;

import io.text,
       io.file;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor,
       bb.log;

import util.inotify;

/**
 * Returns a build logger based on the command options.
 */
Logger buildLogger(in UpdateOptions opts)
{
    import bb.log.file;
    return new FileLogger(stdout, opts.verbose);
}

/**
 * Updates the build.
 *
 * All outputs are brought up-to-date based on their inputs. If '--autopilot' is
 * specified, once the build finishes, we watch for changes to inputs and run
 * another build.
 */
int updateCommand(UpdateOptions opts, GlobalOptions globalOpts)
{
    import std.parallelism : totalCPUs;

    auto logger = buildLogger(opts);

    if (opts.threads == 0)
        opts.threads = totalCPUs;

    auto pool = new TaskPool(opts.threads - 1);
    scope (exit) pool.finish(true);

    immutable color = TextColor(colorOutput(opts.color));

    if (!opts.autopilot)
    {
        return doBuild(opts, pool, logger, color);
    }
    else
    {
        // Do the initial build, checking for changes the old-fashioned way.
        doBuild(opts, pool, logger, color);

        return doAutoBuild(opts, pool, logger, color);
    }
}

int doBuild(UpdateOptions opts, TaskPool pool, Logger logger, TextColor color)
{
    import std.datetime : StopWatch, AutoStart;

    auto sw = StopWatch(AutoStart.yes);

    scope (exit)
    {
        import std.conv : to;
        import core.time : Duration;
        sw.stop();

        if (opts.verbose)
        {
            println(color.status, ":: Total time taken: ", color.reset,
                    cast(Duration)sw.peek());
        }
    }

    try
    {
        auto path = buildDescriptionPath(opts.path);

        auto state = new BuildState(path.stateName);

        state.begin();
        scope (exit)
        {
            if (opts.dryRun)
                state.rollback();
            else
                state.commit();
        }

        syncBuildState(state, pool, path, opts.verbose, color);

        if (opts.verbose)
            println(color.status, ":: Checking for changes...", color.reset);

        queueChanges(state, pool, color);

        update(state, pool, opts.dryRun, opts.verbose, color, logger);
        publishResources(state);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }
    catch (TaskError e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Build failed!", color.reset,
                " See the output above for details.");
        return 1;
    }

    return 0;
}

int doAutoBuild(UpdateOptions opts, TaskPool pool, Logger logger, TextColor color)
{
    string path;
    BuildState state;

    try
    {
        path = buildDescriptionPath(opts.path);
        state = new BuildState(path.stateName);
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    println(color.status, ":: Waiting for changes...", color.reset);

    state.begin();
    scope (exit)
    {
        if (opts.dryRun)
            state.rollback();
        else
            state.commit();
    }

    foreach (changes; ChangeChunks(state))
    {
        scope (exit)
            println(color.status, ":: Waiting for changes...", color.reset);

        try
        {
            size_t changed = 0;

            foreach (v; changes)
            {
                // Check if the resource contents actually changed
                auto r = state[v];

                if (r.update())
                {
                    state.addPending(v);
                    state[v] = r;
                    ++changed;
                }
            }

            if (changed > 0)
            {
                syncBuildState(state, pool, path, opts.verbose, color);
                update(state, pool, opts.dryRun, opts.verbose, color, logger);
            }
        }
        catch (BuildException e)
        {
            stderr.println(color.status, ":: ", color.error,
                    "Error", color.reset, ": ", e.msg);
            continue;
        }
        catch (TaskError e)
        {
            stderr.println(color.status, ":: ", color.error,
                    "Build failed!", color.reset,
                    " See the output above for details.");
            continue;
        }
    }

    publishResources(state);

    return 0;
}

/**
 * Updates the database with any changes to the build description.
 */
void syncBuildState(BuildState state, TaskPool pool, string path, bool verbose, TextColor color)
{
    // TODO: Don't store the build description in the database. The parent build
    // system should store the change state of the build description and tell
    // the child which input resources have changed upon an update.
    auto r = state[BuildState.buildDescId];
    r.path = path;
    if (r.update())
    {
        if (verbose)
            println(color.status, ":: Build description changed. Syncing with the database...",
                    color.reset);

        path.syncState(state, pool);

        // Update the build description resource
        state[BuildState.buildDescId] = r;
    }
}

/**
 * Builds pending vertices.
 */
void update(BuildState state, TaskPool pool, bool dryRun, bool verbose,
        TextColor color, Logger logger)
{
    import std.array : array;
    import std.algorithm.iteration : filter;

    auto resources = state.pending!Resource.array;
    auto tasks     = state.pending!Task.array;

    if (resources.length == 0 && tasks.length == 0)
    {
        if (verbose)
        {
            println(color.status, ":: ", color.success,
                    "Nothing to do. Everything is up to date.", color.reset);
        }

        return;
    }

    // Print what we found.
    if (verbose)
    {
        printfln(" - Found %s%d%s modified resource(s)",
                color.boldBlue, resources.length, color.reset);
        printfln(" - Found %s%d%s pending task(s)",
                color.boldBlue, tasks.length, color.reset);

        println(color.status, ":: Building...", color.reset);
    }

    auto subgraph = state.buildGraph(resources, tasks);
    subgraph.build(state, pool, dryRun, verbose, color, logger);

    if (verbose)
        println(color.status, ":: ", color.success, "Build succeeded", color.reset);
}

/**
 * An infinite input range of chunks of changes. Each item in the range is an
 * array of changed resources. That is, for each item in the range, a new build
 * should be started. Changed files are accumulated over a short period of time.
 * If many files are changed over short period of time, they will be included in
 * one chunk.
 */
struct ChangeChunks
{
    private
    {
        import std.array : Appender;

        enum maxEvents = 32;

        BuildState state;
        Watcher watcher;
        Events!maxEvents events;

        Appender!(Index!Resource[]) current;

        // Mapping of watches to directories. This is needed to find the path to
        // the directory that is being watched.
        string[Watch] watches;
    }

    this(BuildState state)
    {
        import std.path : filenameCmp, dirName;
        import std.container.rbtree;
        import std.file : exists;
        import core.sys.linux.sys.inotify;

        this.state = state;

        watcher = Watcher.init();

        alias less = (a,b) => filenameCmp(a, b) < 0;

        auto rbt = redBlackTree!(less, string)();

        // Find all directories.
        foreach (key; state.enumerate!ResourceKey)
            rbt.insert(dirName(key.path));

        // Watch each (unique) directory. Note that we only watch directories
        // instead of individual files so that we are less likely to run out of
        // file descriptors. Later, we filter out events for files we are not
        // interested in.
        foreach (dir; rbt[])
        {
            if (exists(dir))
            {
                auto watch = watcher.put(dir, IN_CREATE | IN_DELETE);
                watches[watch] = dir;
            }
        }

        events = watcher.events!maxEvents;
    }

    const(Index!Resource)[] front()
    {
        return current.data;
    }

    void popFront()
    {
        import std.path : buildNormalizedPath;

        current.clear();

        // TODO: Use timeouts to watch for changes. When a change is received,
        // add it to the list and wait x milliseconds. If no changes are seen
        // during that time, let the popFront function finish. If another change
        // is seen, add it to the list and start over. This will require
        // asynchronous reads in the underlying inotify wrapper.
        while (!events.empty)
        {
            auto event = events.front;

            scope (success)
                events.popFront();

            auto path = buildNormalizedPath(watches[event.watch], event.name);

            // Since we monitor directories and not specific files, we must
            // check if we received a change that we are actually interested in.
            auto id = state.find(path);
            if (id != Index!Resource.Invalid)
            {
                current.put(id);
                break;
            }
        }
    }

    bool empty()
    {
        return events.empty;
    }
}
