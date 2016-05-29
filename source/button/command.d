/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module button.command;

import button.log;
import button.vertex.resource;

/**
 * Thrown if a command fails.
 */
class CommandError : Exception
{
    this(string msg)
    {
        super(msg);
    }
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
 * A single command.
 */
struct Command
{
    /**
     * Arguments to execute. The first argument is the name of the executable.
     */
    immutable(string)[] args;

    alias args this;

    /**
     * The result of executing a command.
     */
    struct Result
    {
        import core.time : TickDuration;

        /**
         * The command's exit status code
         */
        int status;

        /**
         * Implicit input and output resources this command used.
         */
        Resource[] inputs, outputs;

        /**
         * How long it took the command to run from start to finish.
         */
        TickDuration duration;
    }

    this(immutable(string)[] args)
    {
        assert(args.length > 0, "A command must have >0 arguments");

        this.args = args;
    }

    // Open /dev/null to be used by all child processes as its standard input.
    version (Posix)
    {
        private shared static int devnull;

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
     * Compares this command with another.
     */
    int opCmp()(const auto ref typeof(this) that) const pure nothrow
    {
        import std.algorithm.comparison : cmp;
        return cmp(this.args, that.args);
    }

    /// Ditto
    bool opEquals()(const auto ref typeof(this) that) const pure nothrow
    {
        return this.opCmp(that) == 0;
    }

    unittest
    {
        import std.algorithm.comparison : cmp;

        static assert(Command(["a", "b"]) == Command(["a", "b"]));
        static assert(Command(["a", "b"]) != Command(["a", "c"]));
        static assert(Command(["a", "b"]) <  Command(["a", "c"]));
        static assert(Command(["b", "a"]) >  Command(["a", "b"]));

        static assert(cmp([Command(["a", "b"])], [Command(["a", "b"])]) == 0);
        static assert(cmp([Command(["a", "b"])], [Command(["a", "c"])]) <  0);
        static assert(cmp([Command(["a", "c"])], [Command(["a", "b"])]) >  0);
    }

    /**
     * Returns a string representation of the command.
     *
     * Since the command is in argv format, we format it into a string as one
     * would enter into a shell.
     */
    string toPrettyString() const pure
    {
        import std.array : join;
        import std.algorithm.iteration : map;

        return args.map!(arg => arg.escapeShellArg).join(" ");
    }

    /**
     * Returns a short string representation of the command.
     */
    @property string toPrettyShortString() const pure nothrow
    {
        // TODO: If the program name is "button-deps", use the next one instead.
        return args[0];
    }

    /**
     * Executes the command.
     */
    Result execute(string workDir, TaskLogger logger) const
    {
        import std.datetime : StopWatch, AutoStart;

        auto sw = StopWatch(AutoStart.yes);

        // TODO: Execute the command differently depending on the command line.
        auto result = executeImpl(workDir, logger);

        sw.stop();

        result.duration = sw.peek();

        return result;
    }

    /**
     * Executes the command.
     */
    version (Posix)
    private Result executeImpl(string workDir, TaskLogger logger) const
    {
        // FIXME: Commands should use a separate logger. It only uses the
        // TaskLogger because there used to never be more than one command in a
        // task.

        import core.sys.posix.unistd;
        import core.stdc.stdio : sprintf;

        import io.file.stream : sysEnforce;

        import std.string : toStringz;
        import std.array : array;

        import button.deps : deps;

        Result result;

        int[2] stdfds, inputfds, outputfds;

        sysEnforce(pipe(stdfds)    != -1); // Standard output
        sysEnforce(pipe(inputfds)  != -1); // Implicit inputs
        sysEnforce(pipe(outputfds) != -1); // Implicit outputs

        // Convert D command argument list to a null-terminated argument list
        auto argv = new const(char)*[args.length+1];
        foreach (i; 0 .. args.length)
            argv[i] = toStringz(args[i]);
        argv[$-1] = null;

        // Working directory
        const(char)* cwd = null;
        if (workDir.length)
            cwd = workDir.toStringz();

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

            // Unreachable
        }

        // In the parent process
        close(stdfds[1]);
        close(inputfds[1]);
        close(outputfds[1]);

        // TODO: Parse the resources as they come in instead of all at once at
        // the end.
        auto output = readOutput(stdfds[0], inputfds[0], outputfds[0], logger);
        result.inputs  = deps(output.inputs, workDir).array;
        result.outputs = deps(output.outputs, workDir).array;

        // Wait for the child to exit
        result.status = waitFor(pid);

        return result;
    }
}

private version (Posix)
{
    import std.array : Appender;

    auto readOutput(int stdfd, int inputsfd, int outputsfd, TaskLogger logger)
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
            {
                immutable len = read(stdfd, buf.ptr, buf.length);
                if (len > 0)
                {
                    logger.output(buf[0 .. len]);
                }
                else
                {
                    close(stdfd);
                    stdfd = -1;
                }
            }

            // Read inputs from child
            if (FD_ISSET(inputsfd, &readfds))
                readFromChild(inputsfd, inputs, buf);

            // Read inputs from child
            if (FD_ISSET(outputsfd, &readfds))
                readFromChild(outputsfd, outputs, buf);
        }

        return tuple!("inputs", "outputs")(
                assumeUnique(inputs.data),
                assumeUnique(outputs.data)
                );
    }

    void readFromChild(ref int fd, ref Appender!(ubyte[]) a, ubyte[] buf)
    {
        import core.sys.posix.unistd : read, close;

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
        setenv("BUTTON_INPUTS", inputsenv, 1);
        setenv("BUTTON_OUTPUTS", outputsenv, 1);

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
            fprintf(stderr, "button: Error: Invalid working directory '%s' (%s)\n",
                    cwd, strerror(errno));
            _exit(1);
        }

        execvp(argv[0], argv.ptr);

        // If we get this far, something went wrong. Most likely, the command does
        // not exist.
        fprintf(stderr, "button: Failed executing process '%s' (%s)\n",
                argv[0], strerror(errno));
        _exit(1);
    }
}
