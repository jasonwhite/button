/**
 * Copyright: Copyright Jason White, 2015
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Stores the persistent state of the build.
 */
module bb.state.sqlite;

import bb.vertex, bb.edge;
import sqlite3;

/**
 * Table for holding resource vertices.
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
 * Table for holding task vertices.
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

/**
 * Deserializes a vertex from an SQLite statement. This assumes that the
 * statement has every column of the vertex except the row ID.
 */
Vertex parse(Vertex : Resource)(SQLite3.Statement s)
{
    import std.datetime : SysTime;
    return Resource(s.get!string(0), SysTime(s.get!long(1)));
}

/// Ditto
Vertex parse(Vertex : Task)(SQLite3.Statement s)
{
    import std.conv : to;
    return Task(s.get!string(0).to!(string[]));
}

/**
 * Deserializes an edge from an SQLite statement. This assumes that the
 * statement has every column of the vertex except the row ID.
 */
E parse(E : Edge!(Index!Resource, Index!Task))(SQLite3.Statement s)
{
    return E(
        Index!Resource(s.get!ulong(0)),
        Index!Task(s.get!ulong(1)),
        cast(EdgeType)s.get!int(2)
        );
}

/// Ditto
E parse(E : Edge!(Index!Task, Index!Resource))(SQLite3.Statement s)
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
        // databases created by older versions of this code.
    }

    /**
     * Creates the tables if they don't already exist.
     */
    private void createTables()
    {
        begin();
        scope (success) commit();
        scope (failure) rollback();

        foreach (statement; tables)
            execute(statement);
    }

    /**
     * Inserts a vertex into the database. An exception is thrown if the vertex
     * already exists. Otherwise, the vertex's ID is returned.
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
            immutable vertex = Resource("foo.c", SysTime(9001));

            auto id = state.add(vertex);
            assert(id == 1);
            assert(state[id] == vertex);
        }

        {
            immutable vertex = Task(["foo", "test", "test test"]);

            immutable id = state.add(vertex);
            assert(id == 1);
            assert(state[id] == vertex);
        }
    }

    /**
     * Removes a vertex by the given index. If the vertex does not exist, an
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
     * Returns the vertex state at the given index.
     */
    Resource opIndex(Index!Resource index)
    {
        import std.exception : enforce;
        import std.datetime : SysTime;

        auto s = prepare("SELECT path,lastModified FROM resource WHERE id=?", index);
        enforce(s.step(), "Vertex does not exist.");

        return s.parse!Resource();
    }

    /// Ditto
    Task opIndex(Index!Task index)
    {
        import std.exception : enforce;

        auto s = prepare("SELECT command FROM task WHERE id=?", index);
        enforce(s.step(), "Vertex does not exist.");

        return s.parse!Task();
    }

    /**
     * Returns the vertex state for the given vertex name. Throws an exception if
     * the vertex does not exist.
     *
     * TODO: Only return the vertex's value.
     */
    Resource opIndex(string path)
    {
        import std.exception : enforce;
        import std.datetime : SysTime;

        auto s = prepare("SELECT path,lastModified FROM resource WHERE path=?", path);
        enforce(s.step(), "Vertex does not exist.");

        return s.parse!Resource();
    }

    /// Ditto
    Task opIndex(immutable string[] command)
    {
        import std.exception : enforce;
        import std.conv : to;

        auto s = prepare("SELECT command FROM task WHERE command=?", command.to!string);
        enforce(s.step(), "Vertex does not exist.");

        // This is kind of silly. The only information associated with a task is
        // its command, which is passed in as the argument. However, this
        // function is for uniformity between the two different types of vertices.

        return s.parse!Task();
    }

    unittest
    {
        import std.datetime : SysTime;

        auto state = new BuildState;

        immutable vertex = Resource("foo.c", SysTime(9001));

        auto id = state.add(vertex);
        assert(id == 1);
        assert(state["foo.c"] == vertex);
    }

    unittest
    {
        auto state = new BuildState;

        immutable vertex = Task(["foo", "test", "test test"]);

        immutable id = state.add(vertex);
        assert(id == 1);
        assert(state[["foo", "test", "test test"]] == vertex);
    }

    /**
     * Changes the state of the vertex at the given index. Throws an exception if
     * the vertex does not exist.
     */
    void opIndexAssign(in Resource vertex, Index!Resource index)
    {
        execute(`UPDATE resource SET path=?,lastModified=? WHERE id=?`,
                vertex.path, vertex.modified.stdTime, index);
    }

    /// Ditto
    void opIndexAssign(in Task vertex, Index!Task index)
    {
        import std.conv : to;
        execute(`UPDATE task SET command=? WHERE id=?`,
                vertex.command.to!string, index);
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

        immutable vertices = [
            Resource("foo.o", SysTime(42)),
            Resource("foo.c", SysTime(1337)),
            Resource("bar.c", SysTime(9001)),
            Resource("bar.o", SysTime(0)),
            ];

        foreach (vertex; vertices)
            state.add(vertex);

        assert(equal(vertices, state.resources));
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

        auto vertices = [
            Resource("foo.o", SysTime(42)),
            Resource("foo.c", SysTime(1337)),
            Resource("bar.c", SysTime(9001)),
            Resource("bar.o", SysTime(0)),
            ];

        foreach (vertex; vertices)
            state.add(vertex);

        assert(equal(vertices.sort(), state.sortedResources));
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

        auto vertices = [
            Task(["foo", "arg 1", "arg 2"]),
            Task(["bar", "arg 1"]),
            Task(["baz", "arg 1", "arg 2", "arg 3"]),
            ];

        foreach (vertex; vertices)
            state.add(vertex);

        assert(equal(vertices.sort(), state.sortedTasks));
    }

    /**
     * Adds an edge. Throws an exception if the edge already exists. Returns the
     * index of the edge.
     */
    Index!(Edge!(Resource, Task)) add(Edge!(Index!Resource, Index!Task) edge)
    {
        execute(`INSERT INTO resourceEdge("from", "to", type) VALUES(?, ?, ?)`,
                edge.from, edge.to, edge.type);
        return typeof(return)(lastInsertId);
    }

    /// Ditto
    Index!(Edge!(Task, Resource)) add(Edge!(Index!Task, Index!Resource) edge)
    {
        execute(`INSERT INTO taskEdge("from", "to", type) VALUES(?, ?, ?)`,
                edge.from, edge.to, edge.type);
        return typeof(return)(lastInsertId);
    }

    unittest
    {
        import std.exception : collectException;

        auto state = new BuildState;

        // Creating an edge to non-existent vertices should fail.
        immutable edge = Edge!(Index!Task, Index!Resource)
            (Index!Task(4), Index!Resource(8), EdgeType.explicit);

        assert(collectException!SQLite3Exception(state.add(edge)));
    }

    unittest
    {
        import std.exception : collectException;

        auto state = new BuildState;

        // Create a couple of vertices to link together
        immutable resId = state.add(Resource("foo.c"));
        assert(resId == 1);

        immutable taskId = state.add(Task(["gcc", "foo.c"]));
        assert(taskId == 1);

        immutable edgeId = state.add(Edge!(Index!Resource, Index!Task)(resId, taskId, EdgeType.explicit));
        assert(edgeId == 1);
    }

    /**
     * Removes an edge. Throws an exception if the edge does not exist.
     */
    void remove(Index!(Edge!(Resource, Task)) index)
    {
        execute(`DELETE FROM resourceEdge WHERE id=?`, index);
    }

    /// Ditto
    void remove(Index!(Edge!(Task, Resource)) index)
    {
        execute(`DELETE FROM taskEdge WHERE id=?`, index);
    }

    unittest
    {
        auto state = new BuildState;

        immutable resId  = state.add(Resource("foo.c"));
        immutable taskId = state.add(Task(["gcc", "foo.c"]));
        immutable edgeId = state.add(Edge!(Index!Resource, Index!Task)(resId, taskId, EdgeType.explicit));
        state.remove(edgeId);
        state.remove(resId);
        state.remove(taskId);
    }

    /**
     * Gets the state associated with an edge.
     */
    Edge!(Index!Task, Index!Resource) opIndex(Index!(Edge!(Task, Resource)) index)
    {
        import std.exception : enforce;

        auto s = prepare(
            `SELECT "from","to","type" FROM taskEdge WHERE id=?`, index);
        enforce(s.step(), "Edge does not exist.");

        return s.parse!(typeof(return));
    }

    /// Ditto
    Edge!(Index!Resource, Index!Task) opIndex(Index!(Edge!(Resource, Task)) index)
    {
        import std.exception : enforce;

        auto s = prepare(
            `SELECT "from","to","type" FROM resourceEdge WHERE id=?`, index);
        enforce(s.step(), "Edge does not exist.");

        return s.parse!(typeof(return));
    }

    /// Ditto
    Edge!(Index!Task, Index!Resource) opIndex(Index!Task from, Index!Resource to)
    {
        import std.exception : enforce;

        auto s = prepare(
            `SELECT "from","to","type" FROM taskEdge WHERE "from"=? AND "to"=?`,
            from, to);
        enforce(s.step(), "Edge does not exist.");

        return s.parse!(typeof(return));
    }

    /// Ditto
    Edge!(Index!Resource, Index!Task) opIndex(Index!Resource from, Index!Task to)
    {
        import std.exception : enforce;

        auto s = prepare(
            `SELECT "from","to","type" FROM resourceEdge WHERE "from"=? AND "to"=?`,
            from, to);
        enforce(s.step(), "Edge does not exist.");

        return s.parse!(typeof(return));
    }

    /**
     * Lists all outgoing task edges.
     *
     * TODO: Return pairs of names and values.
     */
    @property auto taskEdges()
    {
        alias T = Edge!(Index!Task, Index!Resource);
        return prepare(`SELECT "from","to","type" FROM taskEdge`)
            .rows!(T, parse!T);
    }

    /// Ditto
    @property auto taskEdgesSorted()
    {
        alias T = Edge!(Index!Task, Index!Resource);
        return prepare(
            `SELECT "from","to","type" FROM taskEdge ORDER BY "from","to"`)
            .rows!(T, parse!T);
    }

    /**
     * Lists all outgoing resource edges.
     *
     * TODO: Return pairs of names and values.
     */
    @property auto resourceEdges()
    {
        alias T = Edge!(Index!Resource, Index!Task);
        return prepare(`SELECT "from","to","type" FROM resourceEdge`)
            .rows!(T, parse!T);
    }

    /// Ditto
    @property auto resourceEdgesSorted()
    {
        alias T = Edge!(Index!Resource, Index!Task);
        return prepare(
            `SELECT "from","to","type" FROM resourceEdge ORDER BY "from","to"`)
            .rows!(T, parse!T);
    }
}
