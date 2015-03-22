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
module bb.state;

import bb.node, bb.task, bb.resource, bb.edge;
import sqlite3;


/**
 * Table for holding resource nodes.
 */
private immutable resourcesTable = """
CREATE TABLE IF NOT EXISTS `resource` (
    `path`          TEXT                NOT NULL,
    `lastModified`  UNSIGNED INTEGER    NOT NULL,
    PRIMARY KEY(path)
);""";

/**
 * Table for holding task nodes.
 */
private immutable tasksTable = """
CREATE TABLE IF NOT EXISTS `task` (
    `command`       TEXT                NOT NULL,
    `created`       UNSIGNED INTEGER    NOT NULL,
    `lastExecuted`  UNSIGNED INTEGER    NOT NULL,
    `lastDuration`  UNSIGNED INTEGER    NOT NULL,
    PRIMARY KEY(command)
);""";

/**
 * Table for holding outgoing edges from resources.
 */
private immutable resourceEdgesTable = """
CREATE TABLE IF NOT EXISTS `resourceEdge` (
    `from`          INTEGER             NOT NULL,
    `to`            INTEGER             NOT NULL,
    `type`          INTEGER             NOT NULL,
    UNIQUE (from, to)
);""";

/**
 * Table for holding outgoing edges from tasks.
 */
private immutable taskEdgesTable = """
CREATE TABLE IF NOT EXISTS `taskEdge` (
    `from`          INTEGER             NOT NULL,
    `to`            INTEGER             NOT NULL,
    `type`          INTEGER             NOT NULL,
    UNIQUE (from, to)
);""";

private immutable tables = [
    resourcesTable,
    tasksTable,
    resourceEdgesTable,
    taskEdgesTable,
];

/**
 * Stores the current state of the build.
 */
class BuildState : SQLite3
{
    /**
     * Open or create the build state file.
     */
    this(string fileName)
    {
        super(fileName);

        // TODO: Do some version checking to find incompatibilities with
        // databases created by older versions of Brilliant Build.
    }

    /**
     * Creates the tables if they don't already exist.
     */
    void initialize()
    {
        begin();
        scope (success) commit();

        foreach (statement; tables)
            execute(statement);
    }

    /**
     * Finds the node with the given name. Throws an exception if the node does
     * not exist.
     */
    version (none) NodeIndex!Resource find(Resource.Identifier name)
    {
        return NodeIndex!Resource(0);
    }

    /**
     * Inserts a node into the database. An exception is thrown if the node
     * already exists. Otherwise, the node's ID is returned.
     */
    NodeIndex!Resource add(in Resource resource)
    {
        static immutable sqlInsert = "INSERT INTO resource VALUES(?, ?)";
        execute(sqlInsert, resource.path, resource.modified.stdTime);
        return NodeIndex!Resource(lastInsertId);
    }

    /// Ditto
    NodeIndex!Task add(in Task task)
    {
        import std.conv : to;
        static immutable sqlInsert = "INSERT INTO task VALUES(?, ?, ?, ?)";

        with (task)
        {
            execute(sqlInsert,
                command.to!string(),
                created.stdTime,
                lastDuration.hnsecs,
                lastExecuted.stdTime
                );
        }

        return NodeIndex!Task(lastInsertId);
    }

    /**
     * Adds an edge. The index of the edge is returned.
     */
    size_t add(NodeIndex!Resource from, NodeIndex!Task to)
    {
        // TODO
        return 0;
    }

    /// Ditto
    size_t add(NodeIndex!Task from, NodeIndex!Resource to)
    {
        // TODO
        return 0;
    }
}
