/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.node.task;

/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;
    import std.datetime : SysTime;

    alias Identifier = immutable(string)[];

    /**
     * The command to execute. The first argument is the name of the executable.
     */
    Identifier command;

    /**
     * When the task was created.
     *
     * TODO: Move this into a log instead.
     */
    //SysTime created;

    /**
     * How long it took to execute this task last time. We can use this to give
     * a rough estimate of how long it will take this time. If the task has
     * never been executed before, this will be a time of length 0.
     *
     * TODO: Move this into a log instead such that a complete history can be
     * kept.
     */
    //TickDuration lastDuration;

    /**
     * When the task was last executed.
     *
     * TODO: Move this into a log instead.
     */
    //SysTime lastExecuted;

    /**
     * Construct a task from the given unique command.
     */
    this(Identifier command)
    {
        this.command = command;
    }

    /**
     * Returns a string representation of the command.
     *
     * Since commands are specified as arrays, we format it into a string as one
     * would enter into a shell.
     */
    string toString() const
    {
        import std.array : join;
        import std.algorithm : map;
        return command.map!(arg => arg.escapeArg).join(" ");
    }

    /**
     * Returns the unique identifier for this node.
     */
    @property const(Identifier) identifier() const pure nothrow
    {
        return command;
    }

    /**
     * Compares this task with another.
     */
    int opCmp()(auto ref Task rhs)
    {
        import std.algorithm : cmp;
        return cmp(this.command, rhs.command);
    }
}

/**
 * Escapes the argument according to the rules of bash, the most commonly used
 * shell.
 *
 * An argument is surrounded with double quotes if it contains any special
 * characters. A backslash is always escaped with another backslash.
 */
private string escapeArg(string arg)
{
    // TODO
    return arg;
}
