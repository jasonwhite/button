/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Finds differences between two ranges.
 *
 * All changes are discovered in O(max(n, m)) where n and m are the length of
 * the two ranges.
 */
module util.change;

import std.range : isInputRange, ElementType;

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
struct Changes(R1, R2, alias pred = "a < b")
    if (isInputRange!R1 && isInputRange!R2 &&
        is(ElementType!R1 == ElementType!R2))
{
    import std.range : ElementType;
    import std.traits : Unqual;
    import std.typecons : Rebindable;

    private alias E = ElementType!R1;

    static if ((is(E == class) || is(E == interface)) &&
               (is(E == const) || is(E == immutable)))
    {
        private alias MutableE = Rebindable!E;
    }
    else static if (is(E : Unqual!E))
    {
        private alias MutableE = Unqual!E;
    }
    else
    {
        private alias MutableE = E;
    }

    private
    {
        // Current change.
        Change!MutableE _current;

        // Next and previous states.
        R1 prev;
        R2 next;

        bool _empty;
    }

    this(R1 prev, R2 next)
    {
        this.prev = prev;
        this.next = next;

        popFront();
    }

    void popFront()
    {
        import std.range : empty, front, popFront;
        import std.functional : binaryFun;

        if (prev.empty && next.empty)
        {
            _empty = true;
        }
        else if (prev.empty)
        {
            _current = Change!E(next.front, ChangeType.added);
            next.popFront();
        }
        else if (next.empty)
        {
            _current = Change!E(prev.front, ChangeType.removed);
            prev.popFront();
        }
        else
        {
            auto a = prev.front;
            auto b = next.front;

            if (binaryFun!pred(a, b))
            {
                // Removed
                _current = Change!E(a, ChangeType.removed);
                prev.popFront();
            }
            else if (binaryFun!pred(b, a))
            {
                // Added
                _current = Change!E(b, ChangeType.added);
                next.popFront();
            }
            else
            {
                // No change
                _current = Change!E(a, ChangeType.none);
                prev.popFront();
                next.popFront();
            }
        }
    }

    @property auto ref front() pure nothrow
    {
        return _current;
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
auto changes(alias pred = "a < b", R1, R2)(R1 previous, R2 next)
{
    return Changes!(R1, R2, pred)(previous, next);
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
