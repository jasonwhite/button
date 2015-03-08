/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
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

        case "update":
            return update(args[1 .. $]);

        case "show":
            return show(args[1 .. $]);

        default:
            displayHelp(args[1 .. $]);
            return 1;
    }
}

/**
 * Display version information.
 */
int displayVersion(string[] args)
{
    stdout.println("TODO: Display version information here.");
    return 0;
}

/**
 * Display help information.
 */
int displayHelp(string[] args)
{
    stdout.println("TODO: Display help information here.");
    return 0;
}

/**
 * Updates the build.
 */
int update(string[] args)
{
    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.parseRules());

    stderr.println(" :: Updating...");

    // TODO: Monitor for changes to resources.
    // TODO: Use database to check for changes to tasks.
    auto changedResources = [
            graph.getIndex!Resource("foo.c"),
        ];
    graph.update(changedResources, []);

    return 0;
}

/**
 * Generates some input for GraphViz.
 */
int show(string[] args)
{
    TaskGraph graph;

    stderr.println(" :: Reading build description from standard input...");
    graph.addRules(stdin.parseRules());

    stderr.println(" :: Generating input for GraphViz ...");
    graph.show(stdout);

    return 0;
}
