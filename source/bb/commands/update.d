/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles command line arguments.
 */
module bb.commands.update;

import io.text, io.file.stdio;

/**
 * Constructs the name of the build state file based on the build description
 * file name.
 */
@property
private string stateName(string fileName) pure nothrow
{
    import std.path : dirName, baseName, buildNormalizedPath;

    immutable string dir  = dirName(fileName);
    immutable string base = baseName(fileName);

    string prefix;

    // Prepend a '.' if there isn't one already.
    if (base.length > 0 && base[0] != '.')
        prefix = ".";

    return buildNormalizedPath(dir, prefix ~ base ~ ".state");
}

unittest
{
    assert("bb.json".stateName == ".bb.json.state");
    assert(".bb.json".stateName == ".bb.json.state");
    assert(".bb.test.json".stateName == ".bb.test.json.state");
    assert("./bb.json".stateName == ".bb.json.state");
    assert("test/bb.json".stateName == "test/.bb.json.state");
    assert("/test/.bb.json".stateName == "/test/.bb.json.state");
}

/**
 * Updates the build.
 *
 * TODO: Add --dryrun option to simulate an update. This would be useful for
 * refactoring the build description.
 */
int update(string[] args)
{
    import io.file;
    import io.range : byBlock;
    import bb.state;

    auto buildDesc = (args.length > 1) ? args[1] : "bb.json";

    try
    {
        auto f = File(buildDesc);
        auto state = new BuildState(buildDesc.stateName);

        // TODO: Diff build description with database
        stderr.println(":: Checking for build description changes...");
    }
    catch (ErrnoException e)
    {
        stderr.println(":: Error: " ~ e.msg);
        return 1;
    }

    stderr.println(":: Updating...");

    // TODO: Build subgraph and update.

    return 0;
}
