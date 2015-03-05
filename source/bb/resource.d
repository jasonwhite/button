/**
 * Copyright: Copyright Jason White, 2015
 * License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Jason White
 */
module bb.resource;

/**
 * Identifier for the resource. This is just the path to the resource.
 */
alias ResourceId = string;

/**
 * A representation of a file on the disk.
 */
struct Resource
{
    import std.datetime : SysTime;

    // File path to the resource
    string path;

    // Last time it was modified, according to the database
    SysTime modified;

    // Number of incoming edges. This is used to detect if a resource is an
    // output for more than 1 task.
    size_t incoming;

    this(string path)
    {
        this.path = path;
    }

    string toString() const pure nothrow
    {
        return path;
    }
}
