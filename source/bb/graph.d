/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 */
module bb.graph;

/**
 * Stupid set implementation using an associative array.
 *
 * This data structure and more should REALLY be in the standard library.
 */
private struct Set(T)
{
    private int[T] items;

    /**
     * Initialize with a list of items.
     */
    this(T[] items)
    {
        foreach (item; items)
            add(item);
    }

    /**
     * Adds a item to the set.
     */
    void add(T item)
    {
        items[item] = typeof(items[item]).init;
    }

    /**
     * Removes an item from the set.
     */
    void remove(T item)
    {
        items.remove(item);
    }
}

/**
 * Bipartite graph.
 */
struct Graph(A,B)
    if (!is(A == B))
{
    private
    {
        Set!B[A] edgesA;
        Set!A[B] edgesB;

        // Uniform way of accessing nodes.
        alias edge(Node : A) = edgesA;
        alias edge(Node : B) = edgesB;
    }

    /**
     * Adds a node.
     */
    void add(Node)(Node node)
    {
        if (node !in edge!Node)
            edge!Node[node] = typeof(edge!Node[node])();
    }

    /**
     * Removes a node and all the incoming and outgoing edges associated with
     * it.
     */
    void remove(Node)(Node node)
    {
        edge!Node.remove(node);
    }

    /**
     * Adds an edge.
     */
    void add(From,To)(From from, To to)
    {
        if (auto p = from in edge!From)
            p.add(to);
        else
            edge!From[from] = typeof(edge!From[from])([to]);
    }

    /**
     * Removes an edge.
     */
    void remove(From, To)(From from, To to)
    {
        edge!From[from].remove(to);
    }

    /**
     * Returns a range of nodes.
     */
    auto nodes(Node)()
    {
        // TODO
    }

    /**
     * Returns a range of edges.
     */
    auto edges(From, To)() const
    {
        // TODO
    }
}

unittest
{
    import bb.index, bb.node;

    auto g = Graph!(Index!Task, Index!Resource)();
    g.add(Index!Task(42));
    g.add(Index!Resource(42));
    g.add(Index!Resource(42), Index!Task(42));
    g.remove(Index!Task(42));
}
