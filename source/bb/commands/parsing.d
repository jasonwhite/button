/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.commands.parsing;

public import darg;

struct GlobalOptions
{
    @Option("help")
    @Help("Prints help on command line usage.")
    OptionFlag help;

    @Option("version")
    @Help("Prints version information.")
    OptionFlag version_;

    @Argument("command", Multiplicity.optional)
    string command;

    @Argument("args", Multiplicity.zeroOrMore)
    string[] args;
}

immutable globalUsage = usageString!GlobalOptions("bb");
immutable globalHelp  = helpString!GlobalOptions();

struct HelpOptions
{
    @Argument("command", Multiplicity.optional)
    @Help("Command to get help on.")
    string command;
}

struct VersionOptions
{
}

struct UpdateOptions
{
    @Option("file", "f")
    @Help("Path to the build description.")
    string path;

    @Option("dryrun", "n")
    @Help("Don't make any functional changes. Just print what might happen.")
    OptionFlag dryRun;

    @Option("threads", "j")
    @Help("The number of threads to use. Default is the number of logical
            cores.")
    @MetaVar("N")
    size_t threads;

    @Option("color")
    @Help("When to colorize the output.")
    @MetaVar("{auto,never,always}")
    string color = "auto";
}

// TODO: Allow graphing of just the build description.
struct GraphOptions
{
    @Option("file", "f")
    @Help("Path to the build description.")
    string path;

    @Option("changes", "C")
    @Help("Only display the subgraph that will be traversed on an update")
    OptionFlag changes;

    @Option("cached")
    @Help("Display the cached graph from the previous build.")
    OptionFlag cached;

    @Option("verbose", "v")
    @Help("Display the full name of each vertex.")
    OptionFlag verbose;

    enum Edges
    {
        explicit = 1 << 0,
        implicit = 1 << 1,
        both = explicit | implicit,
    }

    @Option("edges", "e")
    @Help("Type of edges to show")
    Edges edges = Edges.both;
}

struct StatusOptions
{
    @Option("file", "f")
    @Help("Path to the build description.")
    string path;

    @Option("cached")
    @Help("Display the cached graph from the previous build.")
    OptionFlag cached;

    @Option("color")
    @Help("When to colorize the output.")
    @MetaVar("{auto,never,always}")
    string color = "auto";
}

struct CleanOptions
{
    @Option("file", "f")
    @Help("Path to the build description.")
    string path;

    @Option("dryrun", "n")
    @Help("Don't make any functional changes. Just print what might happen.")
    OptionFlag dryRun;

    @Option("threads", "j")
    @Help("The number of threads to use. Default is the number of logical
            cores.")
    @MetaVar("N")
    size_t threads;

    @Option("color")
    @Help("When to colorize the output.")
    @MetaVar("{auto,never,always}")
    string color = "auto";

    @Option("purge")
    @Help("Delete the build state too.")
    OptionFlag purge;
}

struct GCOptions
{
    @Option("file", "f")
    @Help("Path to the build description.")
    string path;

    @Option("dryrun", "n")
    @Help("Don't make any functional changes. Just print what might happen.")
    OptionFlag dryRun;

    @Option("color")
    @Help("When to colorize the output.")
    @MetaVar("{auto,never,always}")
    string color = "auto";
}

/**
 * Returns the type of the given command.
 */
template Options(string command)
{
    static if (command == "help")
        alias Options = HelpOptions;
    else static if (command == "version")
        alias Options = VersionOptions;
    else static if (command == "update")
        alias Options = UpdateOptions;
    else static if (command == "graph")
        alias Options = GraphOptions;
    else static if (command == "status")
        alias Options = StatusOptions;
    else static if (command == "clean")
        alias Options = CleanOptions;
    else static if (command == "gc")
        alias Options = GCOptions;
    else
    {
        static assert("Invalid command.");
    }
}

/**
 * Parse options for the given command.
 */
alias parseOpts(string command) = parseArgs!(Options!command);

/**
 * Returns the usage string of the given command.
 */
enum Usage(string command) = usageString!(Options!command)("bb "~ command);
