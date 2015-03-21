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
    import io.text, io.file.stdio;
    import std.path : buildPath;
    import std.file : isDir, mkdir;

    // Create .bb directory
    immutable dir = buildPath(baseDir, ".bb");
    if (isDir(dir))
    {
        // TODO: Throw an exception instead.
        stderr.println("Error: Build directory already initialized.");
        return;
    }

    mkdir(dir);

    // Create the database
    import bb.state;
    auto state = BuildState(buildPath(dir, "state"));
    state.initialize();
}
