/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Finds differences between two build states.
 *
 * The state of the previous build description is always kept around in order to
 * detect structural changes to the task graph when the build description
 * changes.
 *
 * The following changes are detected:
 *
 *   - Nodes added or removed
 *   - Edges added or removed
 *
 * If a resource is removed from the build description, it is deleted from the
 * file system.
 *
 * If a task is added to the build description, it is marked as out of date and
 * updated later.
 *
 * If an edge is added or removed, both of its end points are marked as out of
 * date and updated later.
 *
 * All changes are discovered in O(n) where n is the number of nodes and edges.
 */
module bb.change;

import bb.state;

/**
 * Type of a change.
 */
enum ChangeType
{
    none,
    added,
    removed
}

/**
 * Describes a change.
 */
struct Change(T)
{
    T value;
    ChangeType type;
}

/**
 * Range for iterating over changes between two sorted ranges.
 */
struct Changes(Range)
{
    import std.range : ElementType;

    alias T = ElementType!Range;

    private
    {
        // Current change.
        Change!T current;

        // Next and previous states.
        Range prev, next;

        bool _empty;
    }

    this(Range prev, Range next)
    {
        this.prev = prev;
        this.next = next;

        popFront();
    }

    void popFront()
    {
        import std.range : empty, front, popFront;

        if (prev.empty && next.empty)
        {
            _empty = true;
        }
        else if (prev.empty)
        {
            current = Change!T(next.front, ChangeType.added);
            next.popFront();
        }
        else if (next.empty)
        {
            current = Change!T(prev.front, ChangeType.removed);
            prev.popFront();
        }
        else
        {
            immutable a = prev.front;
            immutable b = next.front;

            if (a == b)
            {
                // No change
                current = Change!T(a, ChangeType.none);
                prev.popFront();
                next.popFront();
            }
            else if (a < b)
            {
                // Removed
                current = Change!T(a, ChangeType.removed);
                prev.popFront();
            }
            else
            {
                // Added
                current = Change!T(b, ChangeType.added);
                next.popFront();
            }
        }
    }

    Change!T front() const pure nothrow
    {
        return current;
    }

    bool empty() const pure nothrow
    {
        return _empty;
    }
}

/**
 * Convenience function for constructing a range that finds changes between two
 * ranges.
 */
auto changes(Range)(Range previous, Range next)
{
    return Changes!Range(previous, next);
}

unittest
{
    import std.algorithm : equal;

    immutable prev = "abcd";
    immutable next = "acdef";

    immutable Change!dchar[] result = [
            {'a', ChangeType.none},
            {'b', ChangeType.removed},
            {'c', ChangeType.none},
            {'d', ChangeType.none},
            {'e', ChangeType.added},
            {'f', ChangeType.added},
        ];

    assert(result.equal(changes(prev, next)));
}
