/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.help;

import bb.commands.parsing;

import io.text, io.file.stdio;

int displayHelp(string command)
{
    string usage;
    string help;

    switch (command)
    {
        case "help":
            usage = Usage!"help";
            help  = helpString!(Options!"help")();
            break;
        case "version":
            usage = Usage!"version";
            help  = helpString!(Options!"version")();
            break;
        case "build":
        case "update":
            usage = Usage!"update";
            help  = helpString!(Options!"update")();
            break;
        case "graph":
            usage = Usage!"graph";
            help  = helpString!(Options!"graph")();
            break;
        case "status":
            usage = Usage!"status";
            help  = helpString!(Options!"status")();
            break;
        case "clean":
            usage = Usage!"clean";
            help  = helpString!(Options!"clean")();
            break;
        case "gc":
            usage = Usage!"gc";
            help  = helpString!(Options!"gc")();
            break;

        default:
            printfln("No help available for '%s'.", command);
            return 1;
    }

    if (usage)
        println(usage);
    if (help)
        println(help);

    return 0;
}

private immutable string generalHelp = q"EOS
The most commonly used commands are:
 update          Builds based on changes.
 graph           Writes the build description in GraphViz format.
 help            Prints help on a specific command.

Use 'bb help <command>' to get help on a specific command.
EOS";

/**
 * Display help information.
 */
int displayHelp(Options!"help" opts, GlobalOptions globalOpts)
{
    if (opts.command)
        return displayHelp(opts.command);

    println(globalUsage);
    println(globalHelp);
    println(generalHelp);
    return 0;
}

/**
 * Display version information.
 */
int displayVersion(Options!"version" opts, GlobalOptions globalOpts)
{
    stdout.println("bb version 0.1.0");
    return 0;
}
