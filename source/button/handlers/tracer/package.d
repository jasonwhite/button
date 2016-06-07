/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Traces system calls in the process for precise dependency detection at the
 * cost of speed. This should be the fallback for a command if there is no
 * specialized handler for running it.
 */
module button.handlers.tracer;

version (linux)
{
    // Use strace on Linux.
    public import button.handlers.tracer.strace;
}
else
{
    static assert(false, "Not implemented yet.");
}
