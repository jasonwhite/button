/**
 * Authors: Jason White, Alexey Khmara
 *
 * Description: Wraps the SQLite3 C API in D goodness.
 * This is an updated version of $(WEB https://github.com/bayun/SQLite3-D).
 */
module sqlite3;

import etc.c.sqlite3;
import std.string, std.exception;


/**
 * SQLite3 database wrapper.
 */
class SQLite3
{
    private sqlite3* db;

    /**
     * Opens the given database file.
     */
    this(string file)
    {
        open(file);
    }

    /**
     * Takes control of an existing database handle. The database will still be
     * closed upon destruction.
     */
    this(sqlite3* db)
    {
        this.db = db;
    }

    /**
     * Closes the database.
     */
    ~this()
    {
        close();
    }

    /**
     * Opens or creates a database.
     */
    void open(string file)
    {
        close();

        auto r = sqlite3_open(&(toStringz(file))[0], &db);
        if (r != SQLITE_OK) {
            throw new SQLite3Exception("Cannot open database " ~ file, r);
        }
    }

    /**
     * Takes control of an existing database handle. The database will still be
     * closed upon destruction.
     */
    void open(sqlite3* db)
    {
        close();
        this.db = db;
    }

    /**
     * Closes the database.
     */
    void close()
    {
        if (db)
        {
            sqlite3_close(db);
            db = null;
        }
    }

    /**
     * Convenience functions for beginning, committing, or rolling back a
     * transaction.
     */
    void begin()
    {
        execute("BEGIN");
    }

    /// Ditto
    void commit()
    {
        execute("COMMIT");
    }

    /// Ditto
    void rollback()
    {
        execute("ROLLBACK");
    }

    /**
     * Returns the internal handle to the SQLite3 database. This should only be
     * used if this class does not provide the necessary functionality.
     */
    @property sqlite3* handle() { return db; }

    /**
     * Prepare SQL statement for multiple execution or for parameters binding.
     *
     * If $(D args) are given, they are bound before return, so client can
     * immediately call step() to get rows.
     */
    Statement prepare(T...)(string sql, const auto ref T args)
    {
        auto s = new Statement(sql);
        if (args.length) s.bind(args);
        return s;
    }

    /**
     * Like $(D prepare), but ignores results and returns the number of changed
     * rows.
     */
    uint execute(T...)(string sql, const auto ref T args)
    {
        auto s = prepare(sql, args);

        s.step();

        if (s.columns > 0)
            return this.changes;

        return 0;
    }

    /**
     * Returns the ID of the last row that was inserted.
     */
    @property ulong lastInsertId()
    {
        return sqlite3_last_insert_rowid(db);
    }

    /**
     * Returns the number of rows changed by the last statement.
     */
    @property uint changes()
    {
        return cast(uint)sqlite3_changes(db);
    }

    /**
     * The database is accessed using statements.
     *
     * First, a statement is prepared from a SQL query. Then, values are bound to
     * the parameters in the statement using $(D bind). Finally, the statement is
     * executed using $(D step).
     */
    class Statement
    {
        private sqlite3_stmt *_stmt;

        /**
         * Compiles the SQL statement. Values can then be bound to the
         * parameters of the statement using $(D bind).
         */
        this(string sql)
        {
            auto r = sqlite3_prepare_v2(
                db, toStringz(sql), cast(int)sql.length, &_stmt, null
                );

            enforce(r == SQLITE_OK, new SQLite3Exception(db, r));
        }

        ~this()
        {
            sqlite3_finalize(_stmt);
        }

        /**
         * Returns the internal SQLite3 statement handle. This should only be
         * used if this class does not provide the necessary functionality.
         */
        @property sqlite3_stmt* handle() { return _stmt; }

        /**
         * Returns the number of columns in the result set. This number will be
         * 0 if there is no result set (e.g., INSERT, UPDATE, CREATE TABLE).
         */
        @property uint columns()
        {
            return cast(uint)sqlite3_column_count(_stmt);
        }

        /**
         * Returns the SQL statement string.
         */
        @property string sql() { return fromStringz(sqlite3_sql(_stmt)); }

        /**
         * Binds a value to the statement at a particular index. Indices start
         * at 0.
         */
        void opIndexAssign(T)(const auto ref T v, uint i)
        {
            ++i; // Indices start at 1, not 0

            static if (is(T : int) || is(T : uint))
            {
                auto err = sqlite3_bind_int(_stmt, i, v);
            }
            else static if (is(T : long) || is(T : ulong))
            {
                auto err = sqlite3_bind_int64(_stmt, i, v);
            }
            else static if (is(T : double))
            {
                auto err = sqlite3_bind_double(_stmt, i, v);
            }
            else static if (is(T : const(string)))
            {
                auto err = sqlite3_bind_text(_stmt, i, toStringz(v),
                    cast(int)v.length, SQLITE_TRANSIENT);
            }
            else static if (is(T : const(void*)))
            {
                auto err = sqlite3_bind_blob(_stmt, i, v, cast(int)v.length,
                    SQLITE_TRANSIENT);
            }
            else static if (is(T : typeof(null)))
            {
                auto err = sqlite3_bind_null(_stmt, i);
            }
            else
                static assert(false, "Unsupported SQLite3 type.");

            enforce(err == SQLITE_OK, new SQLite3Exception(db, err));
        }

        /**
         * Gets the index of the bind parameter $(D name).
         */
        uint opIndex(string name)
        {
            int pos = sqlite3_bind_parameter_index(_stmt, toStringz(name));
            enforce(pos <= 0,
                new SQLite3Exception("Invalid bind parameter: " ~ name, SQLITE_ERROR)
                );
            return cast(uint)(pos - 1);
        }

        /**
         * Binds a value by name.
         */
        void opIndexAssign(T)(const auto ref T v, string name)
        {
            this[this[name]] = v;
        }

        /**
         * Bind multiple values to the statement.
         */
        void bind(T...)(const auto ref T args)
        {
            foreach (i, arg; args)
                this[i] = arg;
        }

        /**
         * Steps through the results of the statement. Returns true while there
         * are results or false if there are no more results.
         *
         * Throws: $(D SQLite3Exception) if an error occurs.
         */
        bool step()
        {
            int r = sqlite3_step(_stmt);
            if (r == SQLITE_ROW)
                return true;
            else if (r == SQLITE_DONE)
                return false;
            else
                throw new SQLite3Exception(db, r);
        }

        /**
         * Gets the value from a column.
         */
        T get(T)(uint i)
        in { assert(i < columns); }
        body
        {
            static if (is(T == int) || is(T : uint))
            {
                return cast(T)sqlite3_column_int(_stmt, cast(int)i);
            }
            else static if (is(T == long) || is(T : ulong))
            {
                return cast(T)sqlite3_column_long(_stmt, cast(int)i);
            }
            else static if (is(T == double))
            {
                return sqlite3_column_double(_stmt, cast(int)i);
            }
            else static if (is(T == char[]))
            {
                auto s = sqlite3_column_text(_stmt, cast(int)i);
                int l = sqlite3_column_bytes(_stmt, cast(int)i);
                return s[0 .. l].dup;
            }
            else static if (is(T == string))
            {
                // We can safely cast to string here.
                return cast(string)get!(char[])(i);
            }
            else static if (is(T == void*))
            {
                auto v = sqlite3_column_blob(_stmt, cast(int)i);
                int l = sqlite3_column_bytes(_stmt, cast(int)i);
                return v[0 .. l].dup;
            }
            else
                static assert(false,
                    T.stringof ~ " is an unsupported SQLite3 type"
                    );
        }

        /**
         * Gets the values in the row..
         */
        void getRow(T...)(ref T args)
        {
            foreach (i, arg; args)
                args[i] = get!(typeof(arg))(i);
        }

        /**
         * Returns true if the column index has a NULL value.
         */
        bool isNull(uint i)
        in { assert(i < columns); }
        body
        {
            return sqlite3_column_type(_stmt, cast(int)i) == SQLITE_NULL;
        }

        /**
         * Resets the execution of this statement. This must be called after $(D
         * step) returns false.
         *
         * Note: Bindings are not reset too.
         */
        void reset()
        {
            int r = sqlite3_reset(_stmt);
            enforce(r == SQLITE_OK, new SQLite3Exception(db, r));
        }

        /**
         * Sets all bindings to NULL.
         */
        void clear()
        {
            int r = sqlite3_clear_bindings(_stmt);
            enforce(r == SQLITE_OK, new SQLite3Exception(db, r));
        }
    }
}

// Converts a C-string string to a D-string.
private string fromStringz(const(char)* s)
{
    size_t i = 0;
    while (s[i] != '\0') ++i;
    return s[0 .. i].idup;
}

/**
 * This is thrown if something went wrong in SQLite3.
 */
class SQLite3Exception : Exception
{
    // SQLite3 error code.
    // See http://www.sqlite.org/c3ref/c_abort.html
    int code;

    this(string msg, int code, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
        this.code = code;
    }

    this(sqlite3 *db, int code, string file = __FILE__, size_t line = __LINE__)
    {
        super(fromStringz(sqlite3_errmsg(db)), file, line);
        this.code = code;
    }
}
