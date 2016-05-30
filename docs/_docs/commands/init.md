---
title: "button init"
category: commands
---

Initializes a directory with an initial build description. This is similar to
Git's `init` command.

Note that this command is not mandatory. It is just useful for quickly getting
started on a new project.

This command will *not* overwrite any existing files.

## Examples

To create a `my_project` directory with a starting build description inside:

    $ button init my_project
    $ cd my_project
    $ button build

To create a starting build description in the current directory:

    $ button init

## Positional Arguments

 * `dir`

    The directory to initialize. If not specified, defaults to the current
    directory.
