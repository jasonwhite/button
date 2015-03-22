/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.initialize;

/**
 * Initializes the build directory. This involves:
 *  - Creating the .bb directory
 *  - Creating the database and all its tables
 */
void initialize(string baseDir = ".")
{
    import std.path : buildPath;
    import std.file : exists, isDir, mkdir;

    // Create .bb directory if it doesn't already exist.
    immutable dir = buildPath(baseDir, ".bb");
    if (!exists(dir) || !isDir(dir))
        mkdir(dir);

    // Create the database
    import bb.state;
    auto state = new BuildState(buildPath(dir, "state"));
    state.initialize();

    import bb.resource, bb.task;
    import io.text, io.file.stdio;

    println("foo.c = ", state.add(Resource("foo.c")));
    println("foo.h = ", state.add(Resource("foo.h")));
    println("bar.c = ", state.add(Resource("bar.c")));

    println("gcc 1 = ", state.add(Task(["gcc", "-c", "foo.c", "-o", "foo.o"])));
    println("gcc 2 = ", state.add(Task(["gcc", "-c", "bar.c", "-o", "bar.o"])));
}
