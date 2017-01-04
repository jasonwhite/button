/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * This is the root command handler. That is, this decides which command handler
 * to use.
 */
module button.handler;

import button.events;
import button.resource;
import button.context;

import button.handlers;
import button.command;
import button.task;

alias Handler = void function(
        ref BuildContext ctx,
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        Events events
        );

immutable Handler[string] handlers;
shared static this()
{
    handlers = [
        "button": &recursive,
        "button-lua": &base,
        "dmd": &dmd,
        "gcc": &gcc,
        "g++": &gcc,
        "c++": &gcc,
    ];
}

/**
 * Returns a handler appropriate for the given arguments.
 *
 * In general, this simply looks at the base name of the first argument and
 * determines the tool based on that.
 */
Handler selectHandler(const(string)[] args)
{
    import std.uni : toLower;
    import std.path : baseName, filenameCmp;

    if (args.length)
    {
        auto name = baseName(args[0]);

        // Need case-insensitive comparison on Windows.
        version (Windows)
            name = name.toLower;

        if (auto p = name in handlers)
            return *p;
    }

    return &tracer;
}

void execute(
        ref BuildContext ctx,
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        Events events
        )
{
    auto handler = selectHandler(args);

    handler(ctx, args, workDir, inputs, outputs, events);
}

/**
 * Executes the task.
 */
Task.Result execute(const Task task, ref BuildContext ctx)
{
    import std.array : appender;

    // FIXME: Use a set instead?
    auto inputs  = appender!(Resource[]);
    auto outputs = appender!(Resource[]);

    foreach (command; task.commands)
    {
        auto result = command.execute(ctx, task.workingDirectory);

        // FIXME: Commands may have temporary inputs and outputs. For
        // example, if one command creates a file and a later command
        // deletes it, it should not end up in either of the input or output
        // sets.
        inputs.put(result.inputs);
        outputs.put(result.outputs);
    }

    return Task.Result(inputs.data, outputs.data);
}

/**
 * Executes the command.
 */
Command.Result execute(const Command command, ref BuildContext ctx,
    string workDir)
{
    import std.path : buildPath;
    import std.datetime : StopWatch, AutoStart;
    import button.handler : executeHandler = execute;

    auto inputs  = Resources(ctx.root, workDir);
    auto outputs = Resources(ctx.root, workDir);

    auto sw = StopWatch(AutoStart.yes);

    executeHandler(
            ctx,
            command.args,
            buildPath(ctx.root, workDir),
            inputs, outputs,
            ctx.events
            );

    return Command.Result(inputs.data, outputs.data, sw.peek());
}
