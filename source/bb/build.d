/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Generates input for GraphViz.
 */
module bb.build;

/**
 * Constructs the name of the build state file based on the build description
 * file name.
 */
@property string stateName(string fileName) pure nothrow
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
