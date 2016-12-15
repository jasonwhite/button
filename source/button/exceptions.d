/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Defines exception classes used in button
 *
 * Definitions of exception classes are separated into own module
 * to break module import cycles and reduce overall module inter-depdendency
 */
module button.exceptions;

/**
 * Thrown when an invalid command name is given to $(D runCommand).
 */
class InvalidCommand : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Thrown if a command fails.
 */
class CommandError : Exception
{
    int exitCode;

    this(int exitCode)
    {
        import std.format : format;

        super("Command failed with exit code %d".format(exitCode));

        this.exitCode = exitCode;
    }
}

/**
 * Exception that is thrown on invalid GCC deps syntax.
 */
class MakeParserError : Exception
{
    this(string msg)
    {
        // TODO: Include line information?
        super(msg);
    }
}

/**
 * Thrown when an edge does not exist.
 */
class InvalidEdge : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/**
 * An exception relating to the build.
 */
class BuildException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Thrown if a task fails.
 */
class TaskError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
