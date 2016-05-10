/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Provides a range interface for watching the file system for changes.
 */
module button.watcher;

version (linux)
{
    public import button.watcher.inotify;
}
else version (Windows)
{
    public import button.watcher.windows;
}
else version (OSX)
{
    public import button.watcher.fsevents;
}
else version (FreeBSD)
{
    public import button.watcher.kqueue;
}
else
{
    // TODO: Provide a fallback of using the polling method. That is,
    // periodically stat all the watched files and check if they changed.
    static assert(false, "Not implemented on this platform");
}
