# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Provides useful functions for generating rules for C/C++ projects.
from bb.rules import Rule

def objects(files, flags=[]):
    """
    Generates the rules needed to compile the list of files.

    Parameters:
        - files: List of (source, object) tuples.
        - flags: Extra flags to pass to the compiler.
    """

    args = ['./tools/bb.wrap', 'dmd'] + flags

    for source, output in files:
        yield Rule(
                inputs  = [source],
                task    = args + ['-c', source, '-of' + output],
                outputs = [output]
                )

def link(path, files, flags=[], static=False):
    """
    Returns the rule needed to link the list of files.

    Parameters:
        - files: List of source files or object files.
        - flags: Extra flags to pass to the linker.
    """
    args = ['dmd'] + flags

    if static:
        args.append('-lib')

    return Rule(
            inputs = files,
            task    = args + ['-of' + path] + files,
            outputs = [path]
            )

def binary(path, sources, libraries=[], compiler_flags=[], linker_flags=[]):
    """
    Generates the rules needed to create a binary executable with the given path.

    Parameters:
        - path: Name of the binary without the extension.
        - sources: List of source files to be compiled to object files.
    """

    outputs = [s + '.o' for s in sources]

    # Compile
    yield from objects(zip(sources, outputs), flags=compiler_flags)

    # TODO: Make this more generic
    link_inputs = outputs + ['lib%s.a' % lib for lib in libraries]

    # Link
    yield link(path, link_inputs, flags=linker_flags)

def static_library(path, sources, compiler_flags=[], linker_flags=[]):
    """
    Generates the rules needed to create a static library with the given path.

    Parameters:
        - path: Name of the static library without the extension.
        - sources: List of source files to be included in the library.
    """

    outputs = [s + '.o' for s in sources]

    # Compile
    yield from objects(zip(sources, outputs), flags=compiler_flags)

    path = 'lib' + path + '.a'

    # Link
    yield link(path, outputs, flags=linker_flags, static=True)
