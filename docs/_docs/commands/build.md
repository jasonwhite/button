---
title: "button build"
category: commands
---

Brings the build state up-to-date. This includes:

 1. Updating the internal task graph based on structural changes to the build
    description.

 2. Deleting outputs that should no longer get built. For example, if the task
    `gcc -c foo.c -o foo.o` was removed from the build description, the output
    `foo.o` will be deleted from disk.

 3. Checking for changes to resources. A resource is considered "changed" if
    both its last modification time changed *and* the checksum of its contents
    changed.

 4. Running tasks based on changed inputs.

This will be the command you will use 99% of the time. It is equivalent to an
"incremental build". Although you should never need to do a complete rebuild,
you can do so by running `button clean` followed by `button build`.

## Example

If your root build description `button.json` is in the current working directory
or one of its parent directories, simply run:

    $ button build

If instead your root build description is named something other than
`button.json`, such as `my_build_description.json`, run:

    $ button build --file my_build_description.json

Note that the working directory of Button will change to the directory of the
root build description before running the build.

## Optional Arguments

 * `--file`, `-f <string>`

    Specifies the path to the build description. If not specified, Button
    searches for a file named `button.json` in the current directory and all
    parent directories. Thus, you can invoke this command in any subdirectory of
    your project.

 * `--dryrun`, `-n`

    Don't make any functional changes; just print what might happen. This can be
    useful when refactoring the build description.

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
    However, setting `--watchdir` to the lower file system (so long as it isn't
    also a FUSE file system) will work as expected.

 * `--delay <ulong>`

    Used in conjunction with `--autopilot`. The number of milliseconds to wait
    for additional changes. That is, if after an initial change notification is
    received, the number of milliseconds to wait before starting a build.

    For example, suppose you have `button build --autopilot` running and do a
    `git pull`. Instead of running a build for every file Git changes, the
    changes are *accumulated* and a build is run after `git pull` is completely
    done.

    By default, there is a delay of 50 milliseconds. This should be long enough
    for computer-performed tasks (such as `git pull`) and short enough to be
    imperceptible to a human saving changes in a text editor.

[isatty]: http://linux.die.net/man/3/isatty
