/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Program entry point.
 */
import bb.commands;

import std.meta : AliasSeq;

import io.text;


/**
 * List of command functions.
 */
alias Commands = AliasSeq!(
        helpCommand,
        displayVersion,
        updateCommand,
        statusCommand,
        cleanCommand,
        collectGarbage,
        );

int main(string[] args)
{
    GlobalOptions opts;

    try
    {
        opts = parseArgs!GlobalOptions(args[1 .. $], Config.ignoreUnknown);
    }
    catch (ArgParseException e)
    {
        // Generate usage string at compile time.
        static immutable usage = usageString!GlobalOptions("bb");

        println("Error parsing arguments: ", e.msg, "\n");
        println(usage);
        return 1;
    }

    // Rewrite to "help" command.
    if (opts.help == OptionFlag.yes)
    {
        opts.args = (opts.command ? opts.command : "help") ~ opts.args;
        opts.command = "help";
    }

    if (opts.command == "")
    {
        helpCommand(parseArgs!HelpOptions(opts.args), opts);
        return 1;
    }

    try
    {
        return runCommand!Commands(opts.command, opts);
    }
    catch (InvalidCommand e)
    {
        println(e.msg);
        return 1;
    }
    catch (ArgParseException e)
    {
        println("Error parsing arguments: ", e.msg, "\n");
        displayHelp(opts.command);
        return 1;
    }
}
