---
title: "bb update"
category: commands
---

**Aliases**: `build`

Brings the build state up-to-date. This includes:

 * Updating the internal task graph based on structural changes to the build
   description.
 * Deleting outputs that should no longer get built. For example, if the task
   `gcc -c foo.c -o foo.o` was removed, the output `foo.o` will be deleted from
   disk.
 * Running tasks based on changed inputs.

This will be the command you will use 99% of the time. It is the equivalent to
an "incremental build". You should never need to do a complete rebuild, but if
you do, run `bb clean` followed by a `bb update`.

## Example

If your root build description `bb.json` is in the current working directory or
one of its parent directories, simply run:

    $ bb update

If instead your root build description is named something other than `bb.json`,
such as `my_build_description.json`, run:

    $ bb update --file my_build_description.json

Note that the working directory of Brilliant Build will change to the directory
of the root build description before running the build.

## Optional Arguments

 * `--file`, `-f <string>`
    
    Specifies the path to the build description. If not specified, Brilliant
    Build searches for a file named `bb.json` in the current directory and all
    parent directories. Thus, you can invoke this command in any subdirectory
    of your project.

 * `--dryrun`, `-n`

    Don't make any functional changes; just print what might happen. This can
    be useful when refactoring the build description.

 * `--threads`, `-j N`

    The number of threads to use when executing tasks or checking for changes.
    By default, the number of logical cores is used.

 * `--color {auto,never,always}`
 
    When to colorize the output. If set to `auto` (the default), output is
    colorized if the standard output pipe [refers to a terminal][isatty].

 * `--verbose`, `-v`
    
    Display additional information such as how long each task took to complete
    or the full command line to tasks.

 * `--autopilot`
 
    After completing the initial build, continue watching for changes to inputs
    and building again as necessary. This can be very useful to speed up the
    edit-compile-test cycle of development.

 * `--watchdir <string>`

    Directory to watch for changes in. Used in conjunction with `--autopilot`.
    Since FUSE does not work with inotify, this is useful to use when building
    in a union file system where the "lower" file system contains source code
    and the "upper" file system is where output files are written to. If
    building in the upper file system, inotify cannot receive change events.
    However, watching the lower file system will work.

 * `--delay <ulong>`

    Used in conjunction with `--autopilot`. The number of milliseconds to wait
    for additional changes. That is, if after an initial change notification is
    received, the number of milliseconds to wait before starting a build.

    For example, suppose you have `bb update --autopilot` running and do a `git
    pull`. Instead of running a build for every file Git changes, the changes
    are *accumulated* and a build is run after `git pull` is completely done.

    By default, there is a delay of 50 milliseconds. This should be long enough
    for computer-performed tasks (such as `git pull`) and short enough to be
    imperceptible to a human saving changes in a text editor.

[isatty]: http://linux.die.net/man/3/isatty