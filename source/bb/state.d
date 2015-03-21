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

import bb.task, bb.resource, bb.edge;
import sqlite3;


/**
 * Stores the current state of the build.
 */
struct BuildState
{
    private SQLite3 db;

    this(string fileName)
    {
        db = new SQLite3(fileName);
    }

    /**
     * Creates the tables if they don't already exist.
     */
    void initialize()
    {
        // TODO
    }

    /**
     * Inserts or updates a task. Its index is returned.
     */
    size_t add(Task task)
    {
        // TODO
        return 0;
    }
}
