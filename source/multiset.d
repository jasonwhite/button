/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description: Set data structure.
 */
module multiset;

/**
 * Stupid set implementation using an associative array.
 *
 * This data structure and more should REALLY be in the standard library.
 */
struct MultiSet(T)
{
    private
    {
        // All the items in the set.
        size_t[T] _items;
    }

    /**
     * Initialize with a list of items.
     */
    this(const(T[]) items) pure
    {
        add(items);
    }

    /**
     * Adds a item to the set.
     */
    size_t add(T item) pure
    {
        if (auto p = item in _items)
            return ++(*p);
        else
            return _items[item] = 0;
    }

    // Ditto
    void add(const(T[]) items) pure
    {
        foreach (item; items)
            add(item);
    }

    /**
     * Removes an item from the set and returns the number of remaining
     * duplicates of the item.
     */
    size_t remove(T item) pure
    {
        immutable count = --_items[item];
        if (count == 0)
            _items.remove(item);

        return count;
    }

    /**
     * Returns the number of items in the set.
     */
    @property size_t length() const pure nothrow
    {
        return _items.length;
    }

    /**
     * Returns a range of items in the set. There are no guarantees placed on
     * the order of these items.
     */
    @property auto items() const pure nothrow
    {
        return _items.byKey;
    }

    /**
     * Returns true if the item is in the set.
     */
    bool opIn_r(T item) const pure nothrow
    {
        return (item in _items) != null;
    }

    /**
     * Gets the number of duplicates for the given item.
     */
    size_t opIndex(T item)
    {
        return _items[item];
    }
}
