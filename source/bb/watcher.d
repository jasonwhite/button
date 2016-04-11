/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * High-level interface for using inotify to watch changes to files.
 */
module bb.watcher;

import bb.state;
import bb.vertex.resource;

version (Windows)
{
    static assert(false, "Not implemented yet.");
}

import core.sys.posix.unistd;
import core.sys.linux.sys.inotify;

extern (C) {
    private size_t strnlen(const(char)* s, size_t maxlen);
}

/**
 * Wrapper for an inotify_event.
 */
struct Event
{
    // Maximum size that an inotify_event can b. This is used to determine a
    // good buffer size.
    static immutable max = inotify_event.sizeof * 256;

    int wd;
    uint mask;
    uint cookie;
    const(char)[] name;

    this(inotify_event* e)
    {
        wd     = e.wd;
        mask   = e.mask;
        cookie = e.cookie;
        name   = e.name.ptr[0 .. strnlen(e.name.ptr, e.len)];
    }
}

/**
 * An infinite input range of chunks of changes. Each item in the range is an
 * array of changed resources. That is, for each item in the range, a new build
 * should be started. Changed files are accumulated over a short period of time.
 * If many files are changed over short period of time, they will be included in
 * one chunk.
 */
struct ChangeChunks
{
    private
    {
        import std.array : Appender;

        // inotify file descriptor
        int fd = -1;

        enum maxEvents = 32;

        BuildState state;

        Appender!(Index!Resource[]) current;

        // Mapping of watches to directories. This is needed to find the path to
        // the directory that is being watched.
        string[int] watches;

        // Number of milliseconds to wait
        size_t delay;
    }

    // This is an infinite range.
    enum empty = false;

    this(BuildState state, string watchDir, size_t delay)
    {
        import std.path : filenameCmp, dirName;
        import std.container.rbtree;
        import std.file : exists, buildNormalizedPath;
        import core.sys.linux.sys.inotify;
        import io.file.stream : sysEnforce;

        this.state = state;
        this.delay = delay;

        fd = inotify_init();
        sysEnforce(fd != -1, "Failed to initialize inotify");

        alias less = (a,b) => filenameCmp(a, b) < 0;

        auto rbt = redBlackTree!(less, string)();

        // Find all directories.
        foreach (key; state.enumerate!ResourceKey)
            rbt.insert(dirName(key.path));

        // Watch each (unique) directory. Note that we only watch directories
        // instead of individual files so that we are less likely to run out of
        // file descriptors. Later, we filter out events for files we are not
        // interested in.
        foreach (dir; rbt[])
        {
            auto realDir = buildNormalizedPath(watchDir, dir);

            if (exists(realDir))
            {
                auto watch = addWatch(realDir,
                        IN_CREATE | IN_DELETE | IN_CLOSE_WRITE);
                watches[watch] = dir;
            }
        }

        popFront();
    }

    ~this()
    {
        if (fd != -1)
            close(fd);
    }

    /**
     * Adds a path to be watched by inotify.
     */
    private int addWatch(const(char)[] path, uint mask = IN_ALL_EVENTS)
    {
        import std.internal.cstring : tempCString;
        import io.file.stream : sysEnforce;
        import std.format : format;

        immutable wd = inotify_add_watch(fd, path.tempCString(), mask);

        sysEnforce(wd != -1, "Failed to watch path '%s'".format(path));

        return wd;
    }

    /**
     * Removes a watch from inotify.
     */
    private void removeWatch(int wd)
    {
        inotify_rm_watch(fd, wd);
    }

    /**
     * Returns an array of resource indices that have been (potentially)
     * modified. They still need to be checked to determine if their contents
     * changed.
     */
    const(Index!Resource)[] front()
    {
        return current.data;
    }

    /**
     * Waits for changes.
     */
    void popFront()
    {
        import std.path : buildNormalizedPath;
        import io.file.stream : sysEnforce;

        // Buffer to hold the events. Multiple events can be read at a time.
        ubyte[maxEvents * Event.max] buf;

        // Window into the valid region of the buffer.
        ubyte[] window;

        current.clear();

        while (current.data.length == 0)
        {
            immutable len = read(fd, buf.ptr, buf.length);
            sysEnforce(len != -1, "Failed to read inotify event");

            // Loop over the events that were read in
            window = buf[0 .. len];

            while (window.length)
            {
                auto e = cast(inotify_event*)window.ptr;
                auto event = Event(e);

                auto path = buildNormalizedPath(watches[event.wd], event.name);

                // Since we monitor directories and not specific files, we must
                // check if we received a change that we are actually interested in.
                auto id = state.find(path);
                if (id != Index!Resource.Invalid)
                    current.put(id);

                window = window[inotify_event.sizeof + e.len .. $];
            }
        }
    }
}
