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
    immutable(ubyte)[] stdout;

    // NUL-delimited list of implicit dependencies.
    string inputs, outputs;

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

    // Open /dev/null to be used by all child processes as its standard input.
    version (Posix)
    {
        shared static int devnull;

        shared static this()
        {
            import io.file.stream : sysEnforce;
            import core.sys.posix.fcntl : open, O_RDONLY;
            devnull = open("/dev/null", O_RDONLY);
            sysEnforce(devnull != -1);
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

        import io.file.stream : sysEnforce;

        import std.string : toStringz;
        import std.format : sformat;
        import std.datetime : StopWatch;
        import std.conv : to;

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

        char[16] inputsenv, outputsenv;
        sformat(inputsenv, "%d\0", inputfds[1]);
        sformat(outputsenv, "%d\0", outputfds[1]);

        immutable pid = fork();
        sysEnforce(pid >= 0, "Failed to fork current process");

        // Child process
        if (pid == 0)
        {
            close(stdfds[0]);
            close(inputfds[0]);
            close(outputfds[0]);

            executeChild(argv, this.devnull, stdfds[1], inputfds[1], outputfds[1],
                    inputsenv.ptr, outputsenv.ptr);
        }

        close(stdfds[1]);
        close(inputfds[1]);
        close(outputfds[1]);

        // In the parent process
        auto output = readOutput(stdfds[0], inputfds[0], outputfds[0]);
        result.stdout  = output.stdout;
        result.inputs  = output.inputs;
        result.outputs = output.outputs;

        // Wait for the child to exit
        result.status = waitFor(pid);

        sw.stop();

        result.duration = sw.peek().to!(typeof(result.duration));

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
                nfds = max(nfds,outputsfd);
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
                assumeUnique(cast(string)inputs.data),
                assumeUnique(cast(string)outputs.data)
                );
    }

    void readFromChild(ref int fd, ref Appender!(ubyte[]) a, ubyte[] buf)
    {
        import core.sys.posix.unistd : read, close;
        import io.file.stream : sysEnforce, SysException;

        immutable len = read(fd, buf.ptr, buf.length);
        sysEnforce(len >= 0, "read() failed");

        if (len == 0)
        {
            // End of file. Don't wait on it again.
            close(fd);
            fd = -1;
        }
        else
        {
            a.put(buf[0 .. len]);
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
    void executeChild(const(char*)[] argv,
            int devnull, int stdfd,
            int inputsfd, int outputsfd,
            const(char)* inputsenv, const(char)* outputsenv)
    {
        import core.sys.posix.unistd;
        import core.sys.posix.stdlib : setenv;
        import core.sys.posix.stdio : perror;

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
        setenv("BRILLIANT_BUILD_INPUTS", inputsenv, 1);
        setenv("BRILLIANT_BUILD_OUTPUTS", outputsenv, 1);

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
