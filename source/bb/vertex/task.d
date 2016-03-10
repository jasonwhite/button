/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.vertex.task;

/**
 * A task key must be unique.
 */
struct TaskKey
{
    /**
     * The command to execute. The first argument is the name of the executable.
     */
    immutable(string)[] command;

    /**
     * The working directory for the command relative to the current working
     * directory of the build system. If empty, the current working directory of
     * the build system is used.
     */
    string workingDirectory = "";

    /**
     * Compares this key with another.
     */
    int opCmp()(const auto ref typeof(this) that) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        import std.path : filenameCmp;

        if (immutable result = cmp(this.command, that.command))
            return result;

        return filenameCmp(this.workingDirectory, that.workingDirectory);
    }

    /// Ditto
    bool opEquals()(const auto ref typeof(this) that) const pure nothrow
    {
        return opCmp(that) == 0;
    }
}

unittest
{
    static assert(TaskKey(["a", "b"]) < TaskKey(["a", "c"]));
    static assert(TaskKey(["a", "c"]) > TaskKey(["a", "b"]));
    static assert(TaskKey(["a", "b"], "a") == TaskKey(["a", "b"], "a"));
    static assert(TaskKey(["a", "b"], "a") < TaskKey(["a", "b"], "b"));
}

/**
 * The result of executing a task.
 */
struct TaskResult
{
    import core.time : Duration;

    // The task exit status code
    int status;

    // The standard output and standard error of the task.
    immutable(ubyte)[] stdout;

    // NUL-delimited list of implicit dependencies.
    immutable(ubyte)[] inputs, outputs;

    // How long it took the task to run from start to finish.
    Duration duration;
}

/**
 * Escapes the argument according to the rules of bash, the most commonly used
 * shell. This is mostly used for cosmetic purposes when printing out argument
 * arrays where they could be copy-pasted into a shell.
 */
private string escapeShellArg(string arg) pure
{
    import std.array : appender;
    import std.algorithm.searching : findAmong;
    import std.range : empty;
    import std.exception : assumeUnique;

    if (arg.empty)
        return `""`;

    // Characters that require the string to be quoted.
    static immutable special = " '~*[]?";

    immutable quoted = !arg.findAmong(special).empty;

    auto result = appender!(char[]);

    if (quoted)
        result.put('"');

    foreach (c; arg)
    {
        // Characters to escape
        if (c == '\\' || c == '"' || c == '$' || c == '`')
        {
            result.put("\\");
            result.put(c);
        }
        else
        {
            result.put(c);
        }
    }

    if (quoted)
        result.put('"');

    return assumeUnique(result.data);
}

unittest
{
    assert(escapeShellArg(``) == `""`);
    assert(escapeShellArg(`foo`) == `foo`);
    assert(escapeShellArg(`foo bar`) == `"foo bar"`);
    assert(escapeShellArg(`foo'bar`) == `"foo'bar"`);
    assert(escapeShellArg(`foo?bar`) == `"foo?bar"`);
    assert(escapeShellArg(`foo*.c`) == `"foo*.c"`);
    assert(escapeShellArg(`foo.[ch]`) == `"foo.[ch]"`);
    assert(escapeShellArg(`~foobar`) == `"~foobar"`);
    assert(escapeShellArg(`$PATH`) == `\$PATH`);
    assert(escapeShellArg(`\`) == `\\`);
    assert(escapeShellArg(`foo"bar"`) == `foo\"bar\"`);
    assert(escapeShellArg("`pwd`") == "\\`pwd\\`");
}

/**
 * A representation of a task.
 */
struct Task
{
    import core.time : TickDuration;
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
     * Text to display when running the command. If this is null, the command
     * itself will be displayed. This is useful for reducing the amount of
     * information that is displayed.
     */
    string display;

    this(TaskKey key)
    {
        this.key = key;
    }

    this(immutable(string)[] command, string workDir = "",
            string display = null, SysTime lastExecuted = SysTime.min)
    {
        this.command = command;
        this.display = display;
        this.workingDirectory = workDir;
        this.lastExecuted = lastExecuted;
    }

    // Open /dev/null to be used by all child processes as its standard input.
    version (Posix)
    {
        shared static int devnull;

        shared static this()
        {
            import io.file.stream : sysEnforce;
            import core.sys.posix.fcntl : open, O_RDONLY;
            devnull = open("/dev/null", O_RDONLY);
            sysEnforce(devnull != -1, "Failed to open /dev/null");
        }

        shared static ~this()
        {
            import core.sys.posix.unistd : close;
            close(devnull);
        }
    }

    /**
     * Returns a string representation of the command.
     *
     * Since commands are specified as arrays, we format it into a string as one
     * would enter into a shell.
     */
    string toString(bool verbose = false) const pure
    {
        import std.array : join;
        import std.algorithm.iteration : map;

        if (display && !verbose)
            return display;

        return command.map!(arg => arg.escapeShellArg).join(" ");
    }

    /**
     * Returns a short string representation of the command.
     */
    @property string toShortString() const pure nothrow
    {
        if (display)
            return display;

        if (command.length > 0)
            return command[0];

        return "";
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

    unittest
    {
        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) < Task(["a", "c"]));
        assert(Task(["a", "b"]) > Task(["a", "a"]));

        assert(Task(["a", "b"]) == Task(["a", "b"]));
        assert(Task(["a", "b"], "a") < Task(["a", "b"], "b"));
        assert(Task(["a", "b"], "b") > Task(["a", "b"], "a"));
        assert(Task(["a", "b"], "a") == Task(["a", "b"], "a"));
    }

    /**
     * Executes the task.
     */
    version (Posix) TaskResult execute() const
    {
        import core.sys.posix.unistd;
        import core.stdc.stdio : sprintf;

        import io.file.stream : sysEnforce;

        import std.path : buildPath;
        import std.string : toStringz;
        import std.datetime : StopWatch;
        import core.time : Duration;

        StopWatch sw;
        TaskResult result;

        sw.start();

        int[2] stdfds, inputfds, outputfds;

        sysEnforce(pipe(stdfds) != -1); // Standard output
        sysEnforce(pipe(inputfds) != -1); // Implicit inputs
        sysEnforce(pipe(outputfds) != -1); // Implicit outputs

        // Convert D command argument list to a null-terminated argument list
        auto argv = new const(char)*[command.length+1];
        foreach (i; 0 .. command.length)
            argv[i] = toStringz(command[i]);
        argv[$-1] = null;

        // Working directory
        const(char)* cwd = null;
        if (workingDirectory.length)
            cwd = workingDirectory.toStringz();

        char[16] inputsenv, outputsenv;
        sprintf(inputsenv.ptr, "%d", inputfds[1]);
        sprintf(outputsenv.ptr, "%d", outputfds[1]);

        immutable pid = fork();
        sysEnforce(pid >= 0, "Failed to fork current process");

        // Child process
        if (pid == 0)
        {
            close(stdfds[0]);
            close(inputfds[0]);
            close(outputfds[0]);

            executeChild(argv, cwd, this.devnull, stdfds[1], inputfds[1],
                    outputfds[1], inputsenv.ptr, outputsenv.ptr);
        }

        // In the parent process
        close(stdfds[1]);
        close(inputfds[1]);
        close(outputfds[1]);

        auto output = readOutput(stdfds[0], inputfds[0], outputfds[0]);
        result.stdout  = output.stdout;
        result.inputs  = output.inputs;
        result.outputs = output.outputs;

        // Wait for the child to exit
        result.status = waitFor(pid);

        sw.stop();

        result.duration = cast(Duration)sw.peek();

        return result;
    }

    version (Windows)
    TaskResult execute() const
    {
        // TODO: Implement implicit dependencies
        import std.process : execute;

        import std.datetime : StopWatch;
        import std.conv : to;

        TaskResult result;

        StopWatch sw;
        sw.start();

        auto cmd = execute(command);

        sw.stop();

        result.status = cmd.status;
        result.stdout = cast(const(ubyte)[])cmd.output;
        result.duration = sw.peek().to!(typeof(result.duration));

        return result;
    }
}

private version (Posix)
{
    import std.array : Appender;

    auto readOutput(int stdfd, int inputsfd, int outputsfd)
    {
        import std.array : appender;
        import std.algorithm : max;
        import std.typecons : tuple;
        import std.exception : assumeUnique;

        import core.stdc.errno;
        import core.sys.posix.unistd;
        import core.sys.posix.sys.select;

        import io.file.stream : SysException;

        ubyte[4096] buf;
        fd_set readfds = void;

        auto stdout  = appender!(ubyte[]);
        auto inputs  = appender!(ubyte[]);
        auto outputs = appender!(ubyte[]);

        while (true)
        {
            FD_ZERO(&readfds);

            int nfds = 0;

            if (stdfd != -1)
            {
                FD_SET(stdfd, &readfds);
                nfds = max(nfds, stdfd);
            }

            if (inputsfd != -1)
            {
                FD_SET(inputsfd, &readfds);
                nfds = max(nfds, inputsfd);
            }

            if (outputsfd != -1)
            {
                FD_SET(outputsfd, &readfds);
                nfds = max(nfds, outputsfd);
            }

            if (nfds == 0)
                break;

            immutable r = select(nfds + 1, &readfds, null, null, null);

            if (r == -1)
            {
                if (errno == EINTR)
                    continue;

                throw new SysException("select() failed");
            }

            if (r == 0) break; // Nothing in the set

            // Read stdout/stderr from child
            if (FD_ISSET(stdfd, &readfds))
                readFromChild(stdfd, stdout, buf);

            // Read inputs from child
            if (FD_ISSET(inputsfd, &readfds))
                readFromChild(inputsfd, inputs, buf);

            // Read inputs from child
            if (FD_ISSET(outputsfd, &readfds))
                readFromChild(outputsfd, outputs, buf);
        }

        return tuple!("stdout", "inputs", "outputs")(
                assumeUnique(stdout.data),
                assumeUnique(inputs.data),
                assumeUnique(outputs.data)
                );
    }

    void readFromChild(ref int fd, ref Appender!(ubyte[]) a, ubyte[] buf)
    {
        import core.sys.posix.unistd : read, close;
        import io.file.stream : sysEnforce, SysException;

        immutable len = read(fd, buf.ptr, buf.length);

        if (len > 0)
        {
            a.put(buf[0 .. len]);
        }
        else
        {
            // Either the other end of the pipe was closed or the end of the
            // stream was reached.
            close(fd);
            fd = -1;
        }
    }

    int waitFor(int pid)
    {
        import core.sys.posix.sys.wait;
        import core.stdc.errno;
        import io.file.stream : SysException;
        import core.sys.posix.stdio : perror;

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
    void executeChild(const(char*)[] argv, const(char)* cwd,
            int devnull, int stdfd,
            int inputsfd, int outputsfd,
            const(char)* inputsenv, const(char)* outputsenv)
    {
        import core.sys.posix.unistd;
        import core.sys.posix.stdlib : setenv;
        import core.stdc.stdio : perror, stderr, fprintf;
        import core.stdc.string : strerror;
        import core.stdc.errno : errno;

        import io.file.stream : SysException;
        import io.text;

        // Get standard input from /dev/null. With potentially multiple tasks
        // executing in parallel, the child cannot use standard input.
        if (dup2(devnull, STDIN_FILENO) == -1)
        {
            perror("dup2");
            _exit(1);
        }

        close(devnull);

        // Let the child know two bits of information: (1) that it is being run
        // under this build system and (2) which file descriptors to use to send
        // back dependency information.
        setenv("BB_INPUTS", inputsenv, 1);
        setenv("BB_OUTPUTS", outputsenv, 1);

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

        if (cwd && (chdir(cwd) != 0))
        {
            fprintf(stderr, "bb: Error: Invalid working directory '%s' (%s)\n",
                    cwd, strerror(errno));
            _exit(1);
        }

        execvp(argv[0], argv.ptr);

        // If we get this far, something went wrong. Most likely, the command does
        // not exist.
        fprintf(stderr, "bb: Failed executing process '%s' (%s)\n",
                argv[0], strerror(errno));
        _exit(1);
    }
}
