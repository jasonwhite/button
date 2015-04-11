/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.node.index;

/**
 * Index into a node. This is done to avoid mixing the usage of different node
 * index types.
 */
struct NodeIndex(Node)
{
    ulong index;
    alias index this;
}

/**
 * An index that is not valid.
 *
 * TODO: Exception should probably be used for error handling instead.
 */
enum InvalidIndex(Node) = NodeIndex!Node(ulong.max);
