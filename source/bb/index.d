/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.index;

/**
 * Simple type to leverage the type system to differentiate between storage
 * indices.
 */
struct Index(T, N=ulong)
{
    N index;
    alias index this;
}

unittest
{
    static assert( is(Index!(string, ulong) : ulong));
    static assert( is(Index!(string, int)   : int));
    static assert(!is(Index!(string, ulong) : int));
}
