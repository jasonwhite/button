/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.index;


/**
 * Type to help avoid mixing up indices into arrays who hold different types.
 */
struct Index(T, N=ulong)
{
    N index;
    alias index this;
}

/**
 * An index that is not valid.
 */
//deprecated("Use exception handling instead.")
//enum InvalidIndex(T) = Index!T.max;
