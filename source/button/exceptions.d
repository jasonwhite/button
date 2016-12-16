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

import std.exception : basicExceptionCtors;

/**
 * Thrown when an invalid command name is given to $(D runCommand).
 */
class InvalidCommand : Exception
{
    mixin basicExceptionCtors;
}

/**
 * Thrown if a command fails.
 */
class CommandError : Exception
{
    int exitCode;

    this(int exitCode, string file = __FILE__, int line = __LINE__)
    {
        import std.format : format;

        super("Command failed with exit code %d".format(exitCode), file, line);

        this.exitCode = exitCode;
    }
}

/**
 * Exception that is thrown on invalid GCC deps syntax.
 */
class MakeParserError : Exception
{
    mixin basicExceptionCtors;
}

/**
 * Thrown when an edge does not exist.
 */
class InvalidEdge : Exception
{
    mixin basicExceptionCtors;
}

/**
 * An exception relating to the build.
 */
class BuildException : Exception
{
    mixin basicExceptionCtors;
}

/**
 * Thrown if a task fails.
 */
class TaskError : Exception
{
    mixin basicExceptionCtors;
}
