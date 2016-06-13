/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Program entry point.
 */
import button.app.commands;

import std.meta : AliasSeq;

import io.text;


/**
 * List of command functions.
 */
alias Commands = AliasSeq!(
        helpCommand,
        displayVersion,
        updateCommand,
        graphCommand,
        statusCommand,
        cleanCommand,
        collectGarbage,
        initCommand,
        );

version (unittest)
{
    // Dummy main for unit testing.
    void main() {}
}
else
{
    int main(const(string)[] args)
    {
        GlobalOptions opts;

        try
        {
            opts = parseArgs!GlobalOptions(args[1 .. $], Config.ignoreUnknown);
        }
        catch (ArgParseError e)
        {
            // Generate usage string at compile time.
            static immutable usage = usageString!GlobalOptions("button");

            println("Error parsing arguments: ", e.msg, "\n");
            println(usage);
            return 1;
        }

        // Rewrite to "help" command.
        if (opts.help)
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
        catch (ArgParseError e)
        {
            println("Error parsing arguments: ", e.msg, "\n");
            displayHelp(opts.command);
            return 1;
        }
    }
}
