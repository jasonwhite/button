/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 *
 * Description:
 * Provides a range interface for watching the file system for changes.
 */
module bb.watcher;

version (linux)
{
    public import bb.watcher.inotify;
}
else version (Windows)
{
    public import bb.watcher.windows;
}
else version (OSX)
{
    public import bb.watcher.fsevents;
}
else version (FreeBSD)
{
    public import bb.watcher.kqueue;
}
else
{
    // TODO: Provide a fallback of using the polling method. That is,
    // periodically stat all the watched files and check if they changed.
    static assert(false, "Not implemented on this platform");
}
