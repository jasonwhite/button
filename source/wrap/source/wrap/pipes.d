/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 */
module wrap.pipes;

import io.file.stream : File, FileFlags;

private __gshared File _inputs, _outputs;

shared static this()
{
    import std.process : environment;
    import std.conv : to;

    auto inputsHandle  = environment.get("BRILLIANT_BUILD_INPUTS");
    auto outputsHandle = environment.get("BRILLIANT_BUILD_OUTPUTS");

    if (inputsHandle is null)
        _inputs = File("/dev/null", FileFlags.writeExisting);
    else
        _inputs = File(inputsHandle.to!int);

    if (outputsHandle is null)
        _outputs = File("/dev/null", FileFlags.writeExisting);
    else
        _outputs = File(outputsHandle.to!int);
}

/**
 * Sends an input/output to the parent build system if any.
 */
void sendInput(in char[] path)
{
    if (!_inputs.isOpen) return;

    synchronized
    {
        _inputs.write(path);
        _inputs.write("\0");
    }
}

/// Ditto
void sendOutput(in char[] path)
{
    if (!_outputs.isOpen) return;

    synchronized
    {
        _outputs.write(path);
        _outputs.write("\0");
    }
}
