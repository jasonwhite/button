/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Handles the persistent state of the build. Tasks, resources, and edges are
 * never removed, only disabled. This simplifies indexing into the lists of
 * tasks, resources, and edges.
 */
module bb.state.sqlite;

import bb.index, bb.node, bb.edge;
import sqlite3;

/**
 * Table for holding resource nodes.
 */
private immutable resourcesTable = q"{
CREATE TABLE IF NOT EXISTS resource (
    id              INTEGER NOT NULL,
    path            TEXT    NOT NULL,
    lastModified    INTEGER NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (path)
)}";

/**
 * Table for holding task nodes.
 */
private immutable tasksTable = q"{
CREATE TABLE IF NOT EXISTS task (
    id      INTEGER,
    command TEXT     NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(command)
)}";

/**
 * Table for holding outgoing edges from resources.
 */
private immutable resourceEdgesTable = q"{
CREATE TABLE IF NOT EXISTS resourceEdge (
    id      INTEGER PRIMARY KEY,
    "from"  INTEGER NOT NULL REFERENCES resource(id),
    "to"    INTEGER NOT NULL REFERENCES task(id),
    type    INTEGER NOT NULL,
    UNIQUE("from", "to")
)}";

/**
 * Table for holding outgoing edges from tasks.
 */
private immutable taskEdgesTable = q"{
CREATE TABLE IF NOT EXISTS taskEdge (
    id      INTEGER PRIMARY KEY,
    "from"  INTEGER NOT NULL REFERENCES task(id),
    "to"    INTEGER NOT NULL REFERENCES resource(id),
    type    INTEGER NOT NULL,
    UNIQUE ("from", "to")
)}";

private immutable tables = [
    resourcesTable,
    tasksTable,
    resourceEdgesTable,
    taskEdgesTable,
];


/**
 * Deserializes a node from an SQLite statement. This assumes that the
 * statement has every column of the node.
 */
Node parse(Node : Resource)(SQLite3.Statement s)
{
    import std.datetime : SysTime;
    return Resource(s.get!string(0), SysTime(s.get!long(1)));
}

/// Ditto
Node parse(Node : Task)(SQLite3.Statement s)
{
    import std.conv : to;
    return Task(s.get!string(0).to!(string[]));
}

/**
 * Deserializes an edge from an SQLite statement. This assumes that the
 * statement has every column of the node.
 */
E parse(E : Edge!(Resource, Task))(SQLite3.Statement s)
{
    return E(
        Index!Resource(s.get!ulong(0)),
        Index!Task(s.get!ulong(1)),
        cast(EdgeType)s.get!int(2)
        );
}

/// Ditto
E parse(E : Edge!(Task, Resource))(SQLite3.Statement s)
{
    return E(
        Index!Task(s.get!ulong(0)),
        Index!Resource(s.get!ulong(1)),
        cast(EdgeType)s.get!int(2)
        );
}

/**
 * Stores the current state of the build.
 */
class BuildState : SQLite3
{
    /**
     * Open or create the build state file.
     */
    this(string fileName = ":memory:")
    {
        super(fileName);

        execute("PRAGMA foreign_keys = ON");

        createTables();

        // TODO: Do some version checking to find incompatibilities with
        // databases created by older versions of this software.
    }

    /**
     * Creates the tables if they don't already exist.
     */
    private void createTables()
    {
        begin();
        scope (success) commit();

        foreach (statement; tables)
            execute(statement);
    }

    /**
     * Inserts a node into the database. An exception is thrown if the node
     * already exists. Otherwise, the node's ID is returned.
     */
    Index!Resource add(in Resource resource)
    {
        execute("INSERT INTO resource(path, lastModified) VALUES(?, ?)",
                resource.path, resource.modified.stdTime);
        return Index!Resource(lastInsertId);
    }

    /// Ditto
    Index!Task add(in Task task)
    {
        import std.conv : to;

        execute("INSERT INTO task(command) VALUES(?)", task.command.to!string());

        return Index!Task(lastInsertId);
    }

    unittest
    {
        import std.datetime : SysTime;

        auto state = new BuildState;

        {
            immutable node = Resource("foo.c", SysTime(9001));

            auto id = state.add(node);
            assert(id == 1);
            assert(state[id] == node);
        }

        {
            immutable node = Task(["foo", "test", "test test"]);

            immutable id = state.add(node);
            assert(id == 1);
            assert(state[id] == node);
        }
    }

    /**
     * Removes a node by the given index. If the node does not exist, an
     * exception is thrown.
     */
    void remove(Index!Resource index)
    {
        execute("DELETE FROM resource WHERE id=?", index);
    }

    /// Ditto
    void remove(Index!Task index)
    {
        execute("DELETE FROM task WHERE id=?", index);
    }

    /**
     * Changes the state of the node at the given index. Throws an exception if
     * the node does not exist.
     */
    void update(Index!Resource index, in Resource node)
    {
        // TODO
    }

    /// Ditto
    void update(Index!Task index, in Task node)
    {
        // TODO
    }

    /**
     * Returns the node state at the given index.
     */
    Resource get(Index!Resource index)
    {
        import std.exception : enforce;
        import std.datetime : SysTime;

        auto s = prepare("SELECT path,lastModified FROM resource WHERE id=?", index);
        enforce(s.step(), "Node does not exist.");

        return s.parse!Resource();
    }

    /// Ditto
    Task get(Index!Task index)
    {
        import std.exception : enforce;

        auto s = prepare("SELECT command FROM task WHERE id=?", index);
        enforce(s.step(), "Node does not exist.");

        return s.parse!Task();
    }

    /**
     * Returns the node state for the given node name.
     */
    Resource get(string path)
    {
        import std.exception : enforce;
        import std.datetime : SysTime;

        auto s = prepare("SELECT path,lastModified FROM resource WHERE path=?", path);
        enforce(s.step(), "Node does not exist.");

        return s.parse!Resource();
    }

    /// Ditto
    Task get(immutable string[] command)
    {
        import std.exception : enforce;
        import std.conv : to;

        auto s = prepare("SELECT command FROM task WHERE command=?", command.to!string);
        enforce(s.step(), "Node does not exist.");

        // This is kind of silly. The only information associated with a task is
        // its command, which is passed in as the argument. However, this
        // function is for uniformity between the two different types of nodes.

        return s.parse!Task();
    }

    /**
     * Syntactic sugar for getting node values.
     */
    alias opIndex = get;

    unittest
    {
        import std.datetime : SysTime;

        auto state = new BuildState;

        immutable node = Resource("foo.c", SysTime(9001));

        auto id = state.add(node);
        assert(id == 1);
        assert(state["foo.c"] == node);
    }

    unittest
    {
        auto state = new BuildState;

        immutable node = Task(["foo", "test", "test test"]);

        immutable id = state.add(node);
        assert(id == 1);
        assert(state[["foo", "test", "test test"]] == node);
    }

    /**
     * Returns an input range that iterates over all resources. The order is
     * guaranteed to be the same as the order they were inserted in.
     */
    @property auto resources()
    {
        return prepare("SELECT path,lastModified FROM resource")
            .rows!(Resource, parse!Resource);
    }

    unittest
    {
        import std.algorithm : equal;
        import std.datetime : SysTime;

        auto state = new BuildState;

        immutable nodes = [
            Resource("foo.o", SysTime(42)),
            Resource("foo.c", SysTime(1337)),
            Resource("bar.c", SysTime(9001)),
            Resource("bar.o", SysTime(0)),
            ];

        foreach (node; nodes)
            state.add(node);

        assert(equal(nodes, state.resources));
    }

    /**
     * Returns an input range that iterates over all resources in sorted
     * ascending order.
     */
    @property auto sortedResources()
    {
        return prepare("SELECT path,lastModified FROM resource ORDER BY path")
            .rows!(Resource, parse!Resource);
    }

    unittest
    {
        import std.algorithm : equal, sort;
        import std.datetime : SysTime;

        auto state = new BuildState;

        auto nodes = [
            Resource("foo.o", SysTime(42)),
            Resource("foo.c", SysTime(1337)),
            Resource("bar.c", SysTime(9001)),
            Resource("bar.o", SysTime(0)),
            ];

        foreach (node; nodes)
            state.add(node);

        assert(equal(nodes.sort(), state.sortedResources));
    }

    /**
     * Returns an input range that iterates over all tasks. The order is
     * guaranteed to be the same as the order they were inserted in.
     */
    @property auto tasks()
    {
        return prepare("SELECT command FROM task")
            .rows!(Task, parse!Task);
    }

    unittest
    {
        import std.algorithm : equal, sort;

        auto state = new BuildState;

        immutable tasks = [
            Task(["foo", "arg 1", "arg 2"]),
            Task(["bar", "arg 1"]),
            Task(["baz", "arg 1", "arg 2", "arg 3"]),
            ];

        foreach (task; tasks)
            state.add(task);

        assert(equal(tasks, state.tasks));
    }

    /**
     * Returns an input range that iterates over all tasks in sorted ascending
     * order.
     */
    @property auto sortedTasks()
    {
        return prepare("SELECT command FROM task ORDER BY command")
            .rows!(Task, parse!Task);
    }

    unittest
    {
        import std.algorithm : equal, sort;

        auto state = new BuildState;

        auto nodes = [
            Task(["foo", "arg 1", "arg 2"]),
            Task(["bar", "arg 1"]),
            Task(["baz", "arg 1", "arg 2", "arg 3"]),
            ];

        foreach (node; nodes)
            state.add(node);

        assert(equal(nodes.sort(), state.sortedTasks));
    }

    /**
     * Adds an edge. Throws an exception if the edge already exists. Returns the
     * index of the edge.
     */
    EdgeIndex!(Resource, Task) add(Edge!(Resource, Task) edge)
    {
        execute(`INSERT INTO resourceEdge("from", "to", type) VALUES(?, ?, ?)`,
                edge.from, edge.to, edge.type);
        return typeof(return)(lastInsertId);
    }

    /// Ditto
    EdgeIndex!(Task, Resource) add(Edge!(Task, Resource) edge)
    {
        execute(`INSERT INTO taskEdge("from", "to", type) VALUES(?, ?, ?)`,
                edge.from, edge.to, edge.type);
        return typeof(return)(lastInsertId);
    }

    unittest
    {
        import std.exception : collectException;

        auto state = new BuildState;

        // Creating an edge to non-existent nodes should fail.
        immutable edge = Edge!(Task, Resource)(Index!Task(4),
                Index!Resource(8), EdgeType.explicit);

        assert(collectException!SQLite3Exception(state.add(edge)));
    }

    unittest
    {
        import std.exception : collectException;

        auto state = new BuildState;

        // Create a couple of nodes to link together
        immutable resId = state.add(Resource("foo.c"));
        assert(resId == 1);

        immutable taskId = state.add(Task(["gcc", "foo.c"]));
        assert(taskId == 1);

        immutable edgeId = state.add(Edge!(Resource, Task)(resId, taskId, EdgeType.explicit));
        assert(edgeId == 1);
    }

    /**
     * Removes an edge. Throws an exception if the ege does not exist.
     */
    void remove(EdgeIndex!(Resource, Task) index)
    {
        execute(`DELETE FROM resourceEdge WHERE id=?`, index);
    }

    /// Ditto
    void remove(EdgeIndex!(Task, Resource) index)
    {
        execute(`DELETE FROM taskEdge WHERE id=?`, index);
    }

    unittest
    {
        auto state = new BuildState;

        immutable resId  = state.add(Resource("foo.c"));
        immutable taskId = state.add(Task(["gcc", "foo.c"]));
        immutable edgeId = state.add(Edge!(Resource, Task)(resId, taskId, EdgeType.explicit));
        state.remove(edgeId);
        state.remove(resId);
        state.remove(taskId);
    }

    /**
     * Lists edges
     */
    auto incomingEdges(Index!Resource index)
    {
        return prepare(
            `SELECT "from","to","type" FROM taskEdge WHERE "to"=?`,
            index).rows!(Edge!(Resource, Task), parse!(Edge!(Resource, Task)));
    }

    /// Ditto
    auto outgoingEdges(Index!Resource index)
    {
        return prepare(
            `SELECT "from","to","type" FROM resourceEdge WHERE "from"=?`,
            index).rows!(Edge!(Resource, Task), parse!(Edge!(Resource, Task)));
    }

    /// Ditto
    auto incomingEdges(Index!Task index)
    {
        return prepare(
            `SELECT "from","to","type" FROM resourceEdge WHERE "to"=?`,
            index).rows!(Edge!(Task, Resource), parse!(Edge!(Task, Resource)));
    }

    /// Ditto
    auto outgoingEdges(Index!Task index)
    {
        return prepare(
            `SELECT "from","to","type" FROM taskEdge WHERE "from"=?`,
            index).rows!(Edge!(Task, Resource), parse!(Edge!(Task, Resource)));
    }

    // TODO: More comprehensive tests.
    unittest
    {
        import std.algorithm : equal;
        import std.array : array;

        auto state = new BuildState;
        immutable resId  = state.add(Resource("foo.c"));
        immutable taskId = state.add(Task(["gcc", "foo.c"]));
        immutable edgeId = state.add(Edge!(Resource, Task)(resId, taskId, EdgeType.explicit));

        assert(array(state.incomingEdges(resId)) == []);
    }
}
