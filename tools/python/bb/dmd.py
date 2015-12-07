# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates rules for the Digital Mars D (DMD) compiler.

from bb.core import Target, Rule

from os.path import join

class Generic(Target):

    # Default options to always pass to DMD
    opts = ['-color=on']

    # Path to DMD
    dmd = 'dmd'

    """A generic target to be inherited. For internal use only.
    """
    def __init__(self, *args, imports=[], string_imports=[], versions=[],
            compiler_opts=[], linker_opts=[], objdir=None, bindir='./bin', **kwargs):

        super().__init__(*args, **kwargs)

        self.imports        = imports
        self.string_imports = string_imports
        self.versions       = versions
        self.compiler_opts  = compiler_opts
        self.linker_opts    = linker_opts
        self.bindir         = bindir

        if objdir is None:
            self.objdir = join('obj', self.name)
        else:
            self.objdir = objdir

    def rules(self, deps):
        compiler_args = self.wrapper + \
                        [self.dmd] + \
                        ['-I'+ i for i in self.imports] + \
                        ['-J'+ i for i in self.string_imports] + \
                        ['-version='+ v for v in self.versions] + \
                        self.opts + \
                        self.compiler_opts

        files = [(src, join(self.objdir, src + '.o')) for src in self.srcs if src.endswith('.d')]

        # Build the objects
        for src, output in files:
            yield Rule(
                inputs  = [src],
                task    = compiler_args + ['-c', src, '-of' + output],
                outputs = [output]
                )

        # Link
        linker_args = self.wrapper + [self.dmd] + self.opts + self.linker_opts

        # TODO: Allow C/C++ libraries
        link_inputs = [output for (src, output) in files] + \
                      [join(dep.bindir, dep.path) for dep in deps if isinstance(dep, Library)]

        path = join(self.bindir, self.path)

        yield Rule(
            inputs  = link_inputs,
            task    = linker_args + ['-of' + path] + link_inputs,
            outputs = [path]
            )

class Library(Generic):
    """A D library.

    Parameters:
        - name: Name of the binary without any prefix or extension.
        - srcs: List of D source files to be compiled to object files.
        - deps: List of static library names to be used as dependencies.
                Currently only D static libraries are allowed.
        - compiler_opts: Additional options to pass to the compiler.
        - linker_opts: Additional options to pass to the linker.
    """
    def __init__(self, *args, shared=False, linker_opts=[], **kwargs):

        extra_opts = ['-shared' if shared else '-lib']

        super().__init__(*args, linker_opts=extra_opts + linker_opts, **kwargs)

        self.shared = shared

        if shared:
            self.path = 'lib'+ self.name +'.so'
        else:
            self.path = 'lib'+ self.name +'.a'

class Binary(Generic):
    """A binary executable.

    Parameters:
        - name: Name of the binary without any prefix or extension.
        - srcs: List of D source files to be compiled to object files.
        - deps: List of static library names to be used as dependencies.
                Currently only D static libraries are allowed.
        - compiler_opts: Additional options to pass to the compiler.
        - linker_opts: Additional options to pass to the linker.
    """
    def __init__(self, *args, **kwargs):

        super().__init__(*args, **kwargs)

        self.path = self.name

class Test(Generic):
    """A test. The test is executed as part of the build.

    Parameters:
        - name: Name of the test without any prefix or extension.
        - srcs: List of D source files to be compiled to object files.
        - deps: List of static library names to be used as dependencies.
                Currently only D static libraries are allowed.
        - compiler_opts: Additional options to pass to the compiler.
        - linker_opts: Additional options to pass to the linker.
    """
    def __init__(self, *args, compiler_opts=[], **kwargs):

        super().__init__(
            *args,
            compiler_opts=['-unittest'] + compiler_opts,
            **kwargs
            )

        self.path = self.name

    def rules(self, deps):

        yield from super().rules(deps)

        test_runner = join(self.bindir, self.path)

        yield Rule(
            inputs  = [test_runner],
            task    = [test_runner],
            outputs = [],
            )
