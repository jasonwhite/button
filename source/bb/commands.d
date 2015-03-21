/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands;

import bb.resource, bb.task, bb.rule, bb.taskgraph;
import io.text, io.file.stdio;

/**
 * Parses command line options.
 */
int runCommand(string[] args)
{
    // Default to an update
    if (args.length <= 1)
        return update(args);

    switch (args[1])
    {
        case "version":
            return displayVersion(args[1 .. $]);

        case "help":
            return displayHelp(args[1 .. $]);

        case "init":
            return initialize(args[1 .. $]);

        case "update":
            return update(args[1 .. $]);

        case "show":
            return show(args[1 .. $]);

        case "clean":
            return clean(args[1 .. $]);

        default:
            displayHelp(args[1 .. $]);
            return 1;
    }
}

/**
 * Display version information.
 */
private int displayVersion(string[] args)
{
    stdout.println("TODO: Display version information here.");
    return 0;
}

/**
 * Display help information.
 */
private int displayHelp(string[] args)
{
    stdout.println("TODO: Display help information here.");
    return 0;
}

/**
 * Initialize the build directory.
 */
private int initialize(string[] args)
{
    import bb.initialize;

    if (args.length > 1)
        initialize(args[1]);
    else
        initialize();

    return 0;
}

/**
 * Updates the build.
 */
private int update(string[] args)
{
    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.parseRules());

    stderr.println(" :: Updating...");

    // TODO: Use database to check for changes to resources and tasks.
    auto changedResources = [
            graph.getIndex!Resource("foo.c"),
        ];

    graph.subgraph(changedResources, []).update();

    return 0;
}

/**
 * Generates some input for GraphViz.
 */
private int show(string[] args)
{
    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.parseRules());

    stderr.println(" :: Generating input for GraphViz...");
    graph.show(stdout);

    return 0;
}

/**
 */
private int clean(string[] args)
{
    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.parseRules());

    stderr.println(" :: Cleaning output files...");

    return 0;
}
