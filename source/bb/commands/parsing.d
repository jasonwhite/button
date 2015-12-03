/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.commands.parsing;

import std.meta : AliasSeq;

public import darg;

struct Command
{
    string name;
}

struct Description
{
    string description;
}

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

@Command("help")
@Description("Displays help on a given command.")
struct HelpOptions
{
    @Argument("command", Multiplicity.optional)
    @Help("Command to get help on.")
    string command;
}

@Command("version")
@Description("Prints the current version of the program.")
struct VersionOptions
{
}

@Command("update")
@Command("build")
@Description("Runs a build.")
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
@Command("graph")
@Description("Generates a graph for input into GraphViz.")
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

@Command("status")
@Description("Prints the status of the build. That is, which files have been
        modified and which tasks are pending.")
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

@Command("clean")
@Description("Deletes all build outputs.")
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

@Command("gc")
@Description("EXPERIMENTAL")
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

alias OptionsList = AliasSeq!(
        HelpOptions,
        VersionOptions,
        UpdateOptions,
        GraphOptions,
        StatusOptions,
        CleanOptions,
        GCOptions
        );
