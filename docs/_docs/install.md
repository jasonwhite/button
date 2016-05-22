---
title: "Installation"
category: intro
order: 1
---

Table of contents:

* TOC
{:toc}

---

Button consists of three main components:

 1. `button`: The build system itself.
 2. `button-deps`: The implicit dependency detector.
 3. `button-lua`: The build description generator from Lua scripts.

Optionally, there is also the Makefile-to-Button build description converter
(`button-make`). This is only needed if you want to automatically convert
Makefiles to Button's build description format.

## System Requirements

Supported platforms:

 * Linux

Unsupported platforms:

 * OS X
 * Windows

Supported for OS X and Windows will be coming in the future.

## Compiling From Source

Unfortunately, there are no operating system packages for Button yet. It must be
built from source.

### Installing Dependencies

To build, you'll need [Git][], [Make][], [DMD][] (the D compiler), and [DUB][]
(the D package manager).

On Arch Linux, these can be installed with:

    $ sudo pacman -Sy git base-devel dlang dub

[Git]: https://git-scm.com/
[Make]: https://www.gnu.org/software/make/
[DMD]: http://dlang.org/download.html
[DUB]: http://code.dlang.org/download

### Building `button`

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button.git && cd button
    ```

 2. Build it:

    ```bash
    $ dub build --build=release
    ```

There should now be a `button` executable in the current directory. Copy it to a
directory that is in your `$PATH` and run it to make sure it is working:

    $ button help

### Building `button-deps`

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button-deps.git && cd button-deps
    ```

 2. Build it:

    ```bash
    $ dub build --build=release
    ```

There should now be a `button-deps` executable in the current directory. Copy
it to a directory that is in your `$PATH` and run it to make sure it is working:

    $ button-deps
    Usage: button-deps [--json FILE] -- program [arg...]

### Building `button-lua`

`button-lua` is written in C++ and thus the build process is a little different.

 1. Get the source:

    ```bash
    $ git clone --recursive https://github.com/jasonwhite/button-lua.git && cd button-lua
    ```

 2. Build it:

    ```
    $ make
    ```

There should now be a `button-lua` executable in the current directory. Copy it
to a directory that is in your `$PATH` and run it to make sure it is working:

    $ button-lua
    Usage: button-lua <script> [-o output] [args...]

### Optional: Building `button-make`

This is only needed if you have Makefiles you want to build and/or visualize.

`button-make` is a modified version of GNU Make and thus the build process is
the same as building `make`:

 1. Get the source:

    ```bash
    $ git clone https://github.com/jasonwhite/button-make.git && cd button-make
    ```

 2. Build it:

    ```bash
    $ autoreconf -i
    $ ./configure --prefix=$(pwd)/install --program-prefix=button-
    $ make update
    $ make && make install
    ```

There should now be an `install` directory in the current directory. Copy
`install/bin/button-make` to a directory that is in your `$PATH` and run it to
make sure it is working:

    $ button-make --version

If you run into problems, see GNU Make's own [README.git][] for more information
on building from source. If that fails you, please [submit an
issue](https://github.com/jasonwhite/button-make/issues).

[README.git]: https://github.com/jasonwhite/button-make/blob/master/README.git
