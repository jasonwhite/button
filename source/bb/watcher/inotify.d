/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.watcher.inotify;

version (linux):

import bb.state;
import bb.vertex.resource;

import core.sys.posix.unistd;
import core.sys.posix.poll;
import core.sys.linux.sys.inotify;

extern (C) {
    private size_t strnlen(const(char)* s, size_t maxlen);
}

/**
 * Wrapper for an inotify_event.
 */
private struct Event
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
 * should be started. If many files are changed over short period of time
 * (depending on the delay), they will be included in one chunk.
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

        // Number of milliseconds to wait. Wait indefinitely by default.
        int delay = -1;
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
        import std.conv : to;

        this.state = state;

        if (delay == 0)
            this.delay = -1;
        else
            this.delay = delay.to!int;

        fd = inotify_init1(IN_NONBLOCK);
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
     * Called when events are ready to be read.
     */
    private void handleEvents(ubyte[] buf)
    {
        import std.path : buildNormalizedPath;
        import io.file.stream : SysException;
        import core.stdc.errno : errno, EAGAIN;

        // Window into the valid region of the buffer.
        ubyte[] window;

        while (true)
        {
            immutable len = read(fd, buf.ptr, buf.length);
            if (len == -1)
            {
                // Nothing more to read, break out of the loop.
                if (errno == EAGAIN)
                    break;

                throw new SysException("Failed to read inotify events");
            }

            window = buf[0 .. len];

            // Loop over the events
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

    /**
     * Waits for changes.
     */
    void popFront()
    {
        import io.file.stream : SysException;
        import core.stdc.errno : errno, EINTR;

        pollfd[1] pollFds = [pollfd(fd, POLLIN)];

        // Buffer to hold the events. Multiple events can be read at a time.
        ubyte[maxEvents * Event.max] buf;

        current.clear();

        import io;

        while (true)
        {
            // Wait for more events. If we haven't received any yet, wait
            // indefinitely. Otherwise, give up after a certain delay and return
            // what we've received.
            immutable n = poll(pollFds.ptr, pollFds.length,
                    current.data.length ? delay : -1);
            if (n == -1)
            {
                if (errno == EINTR)
                    continue;

                throw new SysException("Failed to poll for inotify events");
            }
            else if (n == 0)
            {
                // Poll timed out and we've got events, so lets use them.
                if (current.data.length > 0)
                    break;
            }
            else if (n > 0)
            {
                if (pollFds[0].revents & POLLIN)
                    handleEvents(buf);

                // Can't ever time out. Yield any events we have.
                if (delay == -1 && current.data.length > 0)
                    break;
            }
        }
    }
}
