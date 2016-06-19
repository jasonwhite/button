/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Delegates dependency detection to the child process.
 *
 * This is done by creating pipes for the child process to send back the
 * dependency information. The environment variables BUTTON_INPUTS and
 * BUTTON_OUTPUTS are set to the file descriptors that the child should write
 * to. This is also useful for the child process to determine if it is running
 * under this build system or not. The child only needs to check if both of
 * those environment variables are set.
 *
 * This handler should be used for commands that know how to communicate with
 * Button. It is also commonly used by other handlers to run the command.
 */
module button.core.handlers.base;

import button.core.log;
import button.core.resource;

// Open /dev/null to be used by all child processes as its standard input.
version (Posix)
{
    private __gshared static int devnull;

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

version (Posix)
int execute(
        const(string)[] args,
        string workDir,
        ref Resources inputs,
        ref Resources outputs,
        TaskLogger logger
        )
{
    // FIXME: Commands should use a separate logger. It only uses the
    // TaskLogger because there used to never be more than one command in a
    // task.

    import core.sys.posix.unistd;
    import core.stdc.stdio : sprintf;

    import io.file.stream : sysEnforce;

    import std.string : toStringz;
    import std.array : array;

    import button.core.deps : deps;

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

        executeChild(argv, cwd, devnull, stdfds[1], inputfds[1],
                outputfds[1], inputsenv.ptr, outputsenv.ptr);

        // Unreachable
    }

    // In the parent process
    close(stdfds[1]);
    close(inputfds[1]);
    close(outputfds[1]);

    // TODO: Parse the resources as they come in instead of all at once at
    // the end.
    auto implicit = readOutput(stdfds[0], inputfds[0], outputfds[0], logger);

    // Add the inputs and outputs
    inputs.put(implicit.inputs.deps);
    outputs.put(implicit.outputs.deps);

    // Wait for the child to exit
    return waitFor(pid);
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
