/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.clean;

import io.text, io.file.stdio;

import bb.state,
       bb.rule,
       bb.graph,
       bb.build,
       bb.vertex,
       bb.textcolor;

private struct Options
{
    // Path to the build description
    string path;

    // True if this is a dry run.
    bool dryRun;

    // Number of threads to use.
    size_t threads = 0;

    // When to colorize the output.
    string color = "auto";

    // True if the build state should be deleted too.
    bool purge;
}

immutable usage = q"EOS
Usage: bb clean [-f FILE]
EOS";

/**
 * Collects garbage.
 */
int cleanCommand(string[] args)
{
    import std.getopt;

    Options options;

    auto helpInfo = getopt(args,
        "file|f",
            "Path to the build description",
            &options.path,
        "dryrun|n",
            "Don't make any functional changes. Just print what might happen.",
            &options.dryRun,
        "threads|j",
            "The number of threads to use. Default is the number of logical cores.",
            &options.threads,
        "color",
            "When to colorize the output.",
            &options.color,
        "purge",
            "Delete the build state too.",
            &options.purge,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(usage, helpInfo.options);
        return 0;
    }

    immutable color = TextColor(colorOutput(options.color));

    try
    {
        string path = buildDescriptionPath(options.path);

        auto state = new BuildState(path.stateName);
        clean(state);

        if (options.purge)
        {
            import std.file : remove;
            remove(path.stateName);
        }
    }
    catch (BuildException e)
    {
        stderr.println(color.status, ":: ", color.error,
                "Error", color.reset, ": ", e.msg);
        return 1;
    }

    return 0;
}
