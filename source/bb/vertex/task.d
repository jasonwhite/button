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
 * The result of executing a task.
 */
struct TaskResult
{
    import core.time : Duration;

    // The task exit status code
    int status;

    // The standard output and standard error of the task.
    const(ubyte)[] output;

    // The list of implicit dependencies sent back
    string[] inputs, outputs;

    // How long it took the task to run from start to finish.
    Duration duration;
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

    /**
     * Executes the task.
     */
    version (Posix) TaskResult execute() const
    {
        import core.sys.posix.unistd;

        import io.file.pipe : pipe;
        import io.file.stream : sysEnforce;

        import std.string : toStringz;
        import std.format : format;
        import std.datetime : StopWatch;
        import std.conv : to;

        StopWatch sw;
        TaskResult result;

        sw.start();

        auto std = pipe(); // Standard output
        auto deps = pipe(); // Implicit dependencies

        // Convert D command argument list to a null-terminated argument list
        auto argv = new const(char)*[command.length+1];
        foreach (i; 0 .. command.length)
            argv[i] = toStringz(command[i]);
        argv[$-1] = null;

        auto envvar = "%d\0".format(deps.writeEnd.handle);

        immutable pid = fork();
        sysEnforce(pid >= 0, "Failed to fork current process");

        // Child process
        if (pid == 0)
        {
            std.readEnd.close();
            deps.readEnd.close();
            executeChild(argv, std.writeEnd.handle, deps.writeEnd.handle,
                    envvar.ptr);
        }

        std.writeEnd.close();
        deps.writeEnd.close();

        // In the parent process
        result.output = readOutput(std.readEnd);

        // TODO: Read dependencies

        deps.readEnd.close();
        std.readEnd.close();

        result.status = waitFor(pid);

        sw.stop();

        result.duration = sw.peek().to!(typeof(result.duration));

        // TODO: Time how long the process takes to execute
        return result;
    }

    version (Windows)
    TaskResult execute() const
    {
        // TODO: Implement implicit dependencies
        import std.process : execute;

        auto cmd = execute(command);

        return TaskResult(cmd.status, cast(const(ubyte)[])cmd.output);
    }
}

private version (Posix)
{
    ubyte[] readOutput(Stream)(Stream f)
    {
        import std.array : appender;
        import io.range : byChunk;

        ubyte[4096] buf;
        auto output = appender!(ubyte[]);

        foreach (chunk; f.byChunk(buf))
            output.put(chunk);

        return output.data;
    }

    int waitFor(int pid)
    {
        import core.sys.posix.sys.wait;
        import core.stdc.errno;
        import io.file.stream : SysException;

        while (true)
        {
            int status;
            immutable check = waitpid(pid, &status, 0) == -1;
            if (check == -1)
            {
                if (errno == ECHILD)
                {
                    throw new SysException("Child process does not exist");
                }
                else
                {
                    // Keep waiting
                    assert(errno == EINTR);
                    continue;
                }
            }

            if (WIFEXITED(status))
                return WEXITSTATUS(status);
            else if (WIFSIGNALED(status))
                return -WTERMSIG(status);
        }
    }

    /**
     * Executes the child process. This is called after the fork().
     *
     * NOTE: Memory should not be allocated here. It can cause the child process
     * to hang.
     */
    void executeChild(const(char*)[] argv, int stdfd, int depsfd, in char* envvar)
    {
        import core.sys.posix.unistd;
        import core.sys.posix.stdlib : setenv;
        import core.sys.posix.stdio : perror;

        import io.file.stream : SysException;
        import io.text;

        // Close standard input because it won't be possible to write to it when
        // multiple tasks are running simultaneously.
        close(STDIN_FILENO);

        // Let the child know two bits of information: (1) that it is being run
        // under this build system and (2) which file descriptor to send back
        // dependencies on.
        setenv("BRILLIANT_BUILD", envvar, 1);

        // Redirect stdout/stderr to the pipe the parent reads from. There is no
        // differentiation between stdout and stderr.
        if (dup2(stdfd, STDOUT_FILENO) == -1)
        {
            perror("dup2");
            _exit(1);
        }

        if (dup2(stdfd, STDERR_FILENO) == -1)
        {
            perror("dup2");
            _exit(1);
        }

        close(stdfd);

        execvp(argv[0], argv.ptr);

        // If we get this far, something went wrong. Most likely, the command does
        // not exist.
        perror("execvp");
        _exit(1);
    }
}
