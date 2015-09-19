/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.vertex.task;

/**
 * A task identifier.
 */
alias TaskId = immutable(string)[];

/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;
    import std.datetime : SysTime;

    /**
     * The command to execute. The first argument is the name of the executable.
     */
    TaskId command;

    /**
     * Text to display when running the command. If this is null, the command
     * itself will be displayed. This is useful for reducing the amount of
     * information that is displayed.
     */
    //string display;

    /**
     * Time this task was last executed. If this is SysTime.min, then it is
     * taken to mean that the task has never been executed before. This is
     * useful for knowing if a task with no dependencies needs to be executed.
     */
    SysTime lastExecuted = SysTime.min;

    // TODO: Store last execution duration.

    /**
     * Returns a string representation of the command.
     *
     * Since commands are specified as arrays, we format it into a string as one
     * would enter into a shell.
     */
    string toString() const pure nothrow
    {
        import std.array : join;
        import std.algorithm.iteration : map;

        //if (display) return display;

        return command.map!(arg => arg.escapeShellArg).join(" ");
    }

    /**
     * Returns a short string representation of the command.
     */
    @property string shortString() const pure nothrow
    {
        if (command.length > 0)
            return command[0];

        return "";
    }

    /**
     * Returns the unique identifier for this vertex.
     */
    @property inout(TaskId) identifier() inout pure nothrow
    {
        return command;
    }

    /**
     * Compares this task with another.
     */
    int opCmp()(const auto ref typeof(this) rhs) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        return cmp(this.command, rhs.command);
    }

    unittest
    {
        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) == Task(["a", "b"]));
    }
}

/**
 * Escapes the argument according to the rules of bash, the most commonly used
 * shell.
 *
 * An argument is surrounded with double quotes if it contains any special
 * characters. A backslash is always escaped with another backslash.
 */
private string escapeShellArg(string arg) pure nothrow
{
    // TODO
    return arg;
}
