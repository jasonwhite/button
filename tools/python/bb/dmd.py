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

    args = ['dmd'] + flags

    for source, output in files:
        yield Rule(
                inputs  = [source],
                task    = args + ['-c', source, '-of' + output],
                outputs = [output]
                )

def link(path, files, flags=[]):
    """
    Returns the rule needed to link the list of files.

    Parameters:
        - files: List of source files or object files.
        - flags: Extra flags to pass to the linker.
    """
    args = ['dmd'] + flags

    return Rule(
            inputs = files,
            task    = args + ['-of' + path] + files,
            outputs = [path]
            )

def binary(path, sources, compiler_flags=[], linker_flags=[]):
    """
    Generates the rules needed to create a binary executable with the given path.

    Parameters:
        - path: Name of the binary without the extension.
        - sources: List of source files to be compiled to object files.
    """

    outputs = [s + '.o' for s in sources]

    # Compile
    yield from objects(zip(sources, outputs), flags=compiler_flags)

    # Link
    yield link(path, outputs, flags=linker_flags)

