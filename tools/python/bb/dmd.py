# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates rules for the Digital Mars D (DMD) compiler.

from bb.core import Target, Rule

class Library(Target):
    """A D static library.

    Parameters:
        - name: Name of the binary without the prefix or extension.
        - srcs: List of D source files to be compiled to object files.
        - deps: List of static library names to be used as dependencies.
                Currently only D static libraries are allowed.
        - compiler_opts: Additional options to pass to the compiler.
        - linker_opts: Additional options to pass to the linker.
    """
    def __init__(self, name, deps=[], srcs=[], compiler_opts=[],
            linker_opts=[]):
        super().__init__(name=name, deps=deps, srcs=srcs)
        self.compiler_opts = compiler_opts
        self.linker_opts = linker_opts

        self.path = 'lib'+ self.name +'.a'

    def rules(self, deps):
        compiler_args = self.wrapper + ['dmd'] + self.compiler_opts

        files = [(src, src + '.o') for src in self.srcs if src.endswith('.d')]

        # Build the objects
        for src, output in files:
            yield Rule(
                inputs  = [src],
                task    = compiler_args + ['-c', src, '-of' + output],
                outputs = [output]
                )

        # Link
        linker_args = self.wrapper + ['dmd', '-lib'] + self.linker_opts

        link_inputs = [output for (src, output) in files] + \
                      [dep.path for dep in deps if isinstance(dep, Library)]

        yield Rule(
            inputs  = link_inputs,
            task    = linker_args + ['-of' + self.path] + link_inputs,
            outputs = [self.path]
            )

class Binary(Target):
    """A binary executable or shared object.

    Parameters:
        - name: Name of the binary without the prefix or extension.
        - srcs: List of D source files to be compiled to object files.
        - deps: List of static library names to be used as dependencies.
                Currently only D static libraries are allowed.
        - shared: Set to true if this is a shared library. Otherwise, it is a
                  binary executable.
        - compiler_opts: Additional options to pass to the compiler.
        - linker_opts: Additional options to pass to the linker.
    """
    def __init__(self, name, deps=[], srcs=[], shared=False, compiler_opts=[],
            linker_opts=[]):
        super().__init__(name=name, deps=deps, srcs=srcs)
        self.compiler_opts = compiler_opts
        self.linker_opts = linker_opts

        if shared:
            self.path = 'lib'+ self.name +'.a'
        else:
            self.path = self.name

    def rules(self, deps):
        compiler_args = self.wrapper + ['dmd'] + self.compiler_opts

        files = [(src, src + '.o') for src in self.srcs if src.endswith('.d')]

        # Build the objects
        for src, output in files:
            yield Rule(
                inputs  = [src],
                task    = compiler_args + ['-c', src, '-of' + output],
                outputs = [output]
                )

        # Link
        linker_args = self.wrapper + ['dmd'] + self.linker_opts

        # TODO: Allow C/C++ static libraries
        link_inputs = [output for (src, output) in files] + \
                      [dep.path for dep in deps if isinstance(dep, Library)]

        yield Rule(
            inputs  = link_inputs,
            task    = linker_args + ['-of' + self.path] + link_inputs,
            outputs = [self.path]
            )
