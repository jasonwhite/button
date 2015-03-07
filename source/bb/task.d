/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.task;


/**
 * Identifier for the task. This is just the command to execute.
 */
alias TaskName = string[];


/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;

    alias Command = immutable(string)[];
    alias Name = Command;

    /**
     * The command to execute. The first argument is the name of the executable.
     */
    Command command;

    /**
     * Number of incoming edges.
     */
    size_t incoming;

    /**
     * Number of incoming edges that have been satisfied. When this number
     * reaches the number of incoming edges, this node can be visited/processed.
     */
    size_t satisfied;

    /**
     * How long it took to execute this task last time. We can use this to give
     * a rough estimate of how long it will take this time. If the task has
     * never been executed before, this will be a time of length 0.
     */
    TickDuration duration;

    /*
     * TODO: Add more meta data fields such as the date and time when task was
     * created.
     */

    /**
     * Construct a task from the given unique command.
     */
    this(Command command)
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
    @property const(Command) identifier() const pure nothrow
    {
        return command;
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
