/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.task;


/**
 * Identifier for the task. This is just the command to execute.
 */
alias TaskId = string[];


/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;

    alias Command = immutable(string)[];

    // Command to execute. First argument is the name of the executable.
    Command command;

    // Short, human readable name of the task. This is used for display instead
    // of the command if provided.
    string name;

    // How long it took to execute last time.
    TickDuration duration;

    this(Command command)
    {
        this.command = command;
    }

    string toString() const
    {
        if (name !is null)
            return name;

        import std.array : join;
        import std.algorithm : map;
        return command.map!(arg => arg.escapeArg).join(" ");
    }
}

private string escapeArg(string arg)
{
    // TODO
    return arg;
}
