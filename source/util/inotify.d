/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * High-level interface for using inotify to watch changes to files.
 */
module util.inotify;

import core.sys.posix.unistd;
import core.sys.linux.sys.inotify;

extern (C) {
    private size_t strnlen(const(char)* s, size_t maxlen);
}

struct Watch
{
    int wd = -1;
}

struct Event
{
    Watch watch;
    uint mask;
    uint cookie;
    const(char)[] name;
}

struct Events(size_t maxEvents = 16)
{
    private
    {
        // Maximum size an event struct can be, including the file name.
        static immutable maxEventSize = inotify_event.sizeof + 256;

        // File descriptor of inotify.
        int fd = -1;

        // Buffer to hold the events. Potentially multiple events can be read at
        // a time.
        ubyte[maxEvents * maxEventSize] buf;

        // Window into the valid region of the buffer.
        ubyte[] window;
    }

    this(int fd)
    {
        // TODO: Duplicate this file descriptor? That way, the INotify struct
        // can go away, but we can keep reading events.
        this.fd = fd;

        popFront();
    }

    bool empty()
    {
        return window.length == 0;
    }

    void popFront()
    {
        import io.file.stream : sysEnforce;

        if (window.length > 0)
        {
            // Slide the window over by one event
            inotify_event* e = cast(inotify_event*)window.ptr;
            window = window[inotify_event.sizeof + e.len .. $];
        }

        if (window.length == 0)
        {
            // Read the next batch of events.
            immutable len = read(fd, buf.ptr, buf.length);
            sysEnforce(len != -1, "Failed to read inotify event");
            window = buf[0 .. len];
        }
    }

    Event front()
    {
        inotify_event* e = cast(inotify_event*)window.ptr;

        return Event(
                Watch(e.wd),
                e.mask,
                e.cookie,
                e.name.ptr[0 .. strnlen(e.name.ptr, e.len)]
                );
    }
}

struct Watcher
{
    private int fd = -1;

    this(int fd)
    {
        this.fd = fd;
    }

    @disable this(this);

    ~this()
    {
        if (fd != -1)
            close(fd);
    }

    static typeof(this) init()
    {
        import io.file.stream : sysEnforce;

        int fd = inotify_init();

        sysEnforce(fd != -1, "Failed to initialize inotify");

        return typeof(this)(fd);
    }

    Watch put(const(char)[] path, uint mask = IN_ALL_EVENTS)
    {
        import std.internal.cstring : tempCString;
        import io.file.stream : sysEnforce;
        import std.format : format;

        immutable wd = inotify_add_watch(fd, path.tempCString(), mask);

        sysEnforce(wd != -1, "Failed to watch path '%s'".format(path));

        return Watch(wd);
    }

    void remove(Watch watch)
    {
        inotify_rm_watch(fd, watch.wd);
    }

    @property
    Events!maxEvents events(size_t maxEvents = 16)()
    {
        return Events!maxEvents(fd);
    }
}
