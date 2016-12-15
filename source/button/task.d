/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.task;

import button.command;
import button.log;
import button.resource;
import button.context;
import button.exceptions;

/**
 * A task key must be unique.
 */
struct TaskKey
{
    /**
     * The commands to execute in sequential order. The first argument is the
     * name of the executable.
     */
    immutable(Command)[] commands;

    /**
     * The working directory for the commands, relative to the current working
     * directory of the build system. If empty, the current working directory of
     * the build system is used.
     */
    string workingDirectory = "";

    this(immutable(Command)[] commands, string workingDirectory = "")
    {
        assert(commands.length, "A task must have >0 commands");

        this.commands = commands;
        this.workingDirectory = workingDirectory;
    }

    /**
     * Compares this key with another.
     */
    int opCmp()(const auto ref typeof(this) that) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        import std.path : filenameCmp;

        if (immutable result = cmp(this.commands, that.commands))
            return result;

        return filenameCmp(this.workingDirectory, that.workingDirectory);
    }

    /// Ditto
    bool opEquals()(const auto ref typeof(this) that) const pure nothrow
    {
        return this.opCmp(that) == 0;
    }
}

unittest
{
    // Comparison
    static assert(TaskKey([Command(["a", "b"])]) < TaskKey([Command(["a", "c"])]));
    static assert(TaskKey([Command(["a", "c"])]) > TaskKey([Command(["a", "b"])]));
    static assert(TaskKey([Command(["a", "b"])], "a") == TaskKey([Command(["a", "b"])], "a"));
    static assert(TaskKey([Command(["a", "b"])], "a") != TaskKey([Command(["a", "b"])], "b"));
    static assert(TaskKey([Command(["a", "b"])], "a") <  TaskKey([Command(["a", "b"])], "b"));
}

unittest
{
    import std.conv : to;

    // Converting commands to a string. This is used to store/retrieve tasks in
    // the database.

    immutable t = TaskKey([
            Command(["foo", "bar"]),
            Command(["baz"]),
            ]);

    assert(t.commands.to!string == `[["foo", "bar"], ["baz"]]`);
}

/**
 * A representation of a task.
 */
struct Task
{
    import std.datetime : SysTime;

    TaskKey key;

    alias key this;

    /**
     * Time this task was last executed. If this is SysTime.min, then it is
     * taken to mean that the task has never been executed before. This is
     * useful for knowing if a task with no dependencies needs to be executed.
     */
    SysTime lastExecuted = SysTime.min;

    /**
     * Text to display when running the task. If this is null, the commands
     * themselves will be displayed. This is useful for reducing the amount of
     * noise that is displayed.
     */
    string display;

    /**
     * The result of executing a task.
     */
    struct Result
    {
        /**
         * List of raw byte arrays of implicit inputs/outputs. There is one byte
         * array per command.
         */
        Resource[] inputs, outputs;
    }

    this(TaskKey key)
    {
        this.key = key;
    }

    this(immutable(Command)[] commands, string workDir = "",
            string display = null, SysTime lastExecuted = SysTime.min)
    {
        assert(commands.length, "A task must have >0 commands");

        this.commands = commands;
        this.display = display;
        this.workingDirectory = workDir;
        this.lastExecuted = lastExecuted;
    }

    /**
     * Returns a string representation of the task.
     *
     * Since individual commands are in argv format, we format it into a string
     * as one would enter into a shell.
     */
    string toPrettyString(bool verbose = false) const pure
    {
        import std.array : join;
        import std.algorithm.iteration : map;

        if (display && !verbose)
            return display;

        // Just use the first command
        return commands[0].toPrettyString;
    }

    /**
     * Returns a short string representation of the task.
     */
    @property string toPrettyShortString() const pure nothrow
    {
        if (display)
            return display;

        // Just use the first command
        return commands[0].toPrettyShortString;
    }

    /**
     * Compares this task with another.
     */
    int opCmp()(const auto ref typeof(this) that) const pure nothrow
    {
        return this.key.opCmp(that.key);
    }

    /// Ditto
    bool opEquals()(const auto ref typeof(this) that) const pure nothrow
    {
        return opCmp(that) == 0;
    }

    version (none) unittest
    {
        assert(Task([["a", "b"]]) < Task([["a", "c"]]));
        assert(Task([["a", "b"]]) > Task([["a", "a"]]));

        assert(Task([["a", "b"]]) < Task([["a", "c"]]));
        assert(Task([["a", "b"]]) > Task([["a", "a"]]));

        assert(Task([["a", "b"]])      == Task([["a", "b"]]));
        assert(Task([["a", "b"]], "a") <  Task([["a", "b"]], "b"));
        assert(Task([["a", "b"]], "b") >  Task([["a", "b"]], "a"));
        assert(Task([["a", "b"]], "a") == Task([["a", "b"]], "a"));
    }

    Result execute(ref BuildContext ctx, TaskLogger logger)
    {
        import std.array : appender;

        // FIXME: Use a set instead?
        auto inputs  = appender!(Resource[]);
        auto outputs = appender!(Resource[]);

        foreach (command; commands)
        {
            auto result = command.execute(ctx, workingDirectory, logger);

            // FIXME: Commands may have temporary inputs and outputs. For
            // example, if one command creates a file and a later command
            // deletes it, it should not end up in either of the input or output
            // sets.
            inputs.put(result.inputs);
            outputs.put(result.outputs);
        }

        return Result(inputs.data, outputs.data);
    }
}
