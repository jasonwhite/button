---
title: "button convert"
category: commands
---

Converts the JSON build description to another format to be used by other build
systems.

Currently, only Bash output is supported. Support for other formats may come in
the future if there is a need for them.

This command can be useful to lower the barrier for contributing to a project.
If someone has to install Button in order to build your project, that is yet
another filter to potential contributors. To help mitigate this effect, you can
generate a shell script using this command and commit the output to your
repository. Ideally, generating the shell script and committing it should be
automated with a continuous integration server. To aid this workflow, the output
of `button convert` is deterministic so that it plays well with version control
systems.

## Examples

To generate and run a Bash script of the build description `button.json`:

    $ button convert build.sh
    $ ./build.sh

If the build description is in another file, use the `-f` flag to specify where
it is:

    $ button convert -f path.to.build.description.json build.sh
    $ ./build.sh

## Positional Arguments

 * `output`

    The file to write the output to. Depending on the format and platform, this
    file is made executable.

## Optional Arguments

 * `--file`, `-f <string>`

    Specifies the path to the build description. If not specified, Button
    searches for a file named `button.json` in the current directory and all
    parent directories. Thus, you can invoke this command in any subdirectory of
    your project.

 * `--format {bash}`

    Format of the build description to convert to. Defaults to `bash`.

    Only `bash` is currently supported.
