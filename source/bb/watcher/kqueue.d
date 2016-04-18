/**
 * Copyright: Copyright Jason White, 2016
 * License:   MIT
 * Authors:   Jason White
 */
module bb.watcher.kqueue;

version (Windows):

// TODO: Use kqueue to watch for file system changes.
static assert(false, "Not implemented yet");
