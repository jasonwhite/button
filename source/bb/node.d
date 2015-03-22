/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.node;

/**
 * Index into a node. This is done to avoid mixing the usage of different node
 * index types.
 */
struct NodeIndex(Node)
{
    ulong index;
    alias index this;
}

enum InvalidIndex = size_t.max;
