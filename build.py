#!/bin/env python3
# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates the rules necessary to build Brilliant Build.
import bb

from glob import glob

# Wrap all commands with the bootstrapped wrapper to catch dependencies.
bb.core.Target.wrapper = ['./bb-wrap-bootstrap']

def targets():

    dmd_opts = ['-release', '-w']

    yield bb.dmd.Library(
        name = 'io',
        srcs = glob('source/io/source/io/**/*.d', recursive = True),
        imports = ['source/io/source'],
        compiler_opts = dmd_opts,
        )

    yield bb.dmd.Test(
        name = 'io_test',
        srcs = bb.glob(['source/io/source/io/**/*.d']),
        imports = ['source/io/source'],
        compiler_opts = dmd_opts,
        linker_opts = ['-main'],
        )

    yield bb.dmd.Binary(
        name = 'bb',
        deps = ['io'],
        srcs = bb.glob([
            'source/util/*.d',
            'source/bb/**/*.d',
            'source/darg/source/*.d'
            ]),
        imports = ['source', 'source/darg/source', 'source/io/source'],
        compiler_opts = dmd_opts,
        linker_opts = ['-L-lsqlite3'],
        )

    yield bb.dmd.Test(
        name = 'bb_test',
        deps = ['io'],
        srcs = bb.glob([
            'source/util/*.d',
            'source/bb/**/*.d',
            'source/darg/source/*.d',
            ])
        imports = ['source', 'source/darg/source', 'source/io/source'],
        compiler_opts = dmd_opts,
        linker_opts = ['-L-lsqlite3'],
        )

    yield bb.dmd.Binary(
        name = 'bbwrapper',
        deps = ['io'],
        srcs = bb.glob(['source/wrap/source/wrap/**/*.d']),
        imports = ['source/wrap/source', 'source/io/source'],
        compiler_opts = dmd_opts,
        )

    yield bb.dmd.Test(
        name = 'bbwrapper_test',
        deps = ['io'],
        srcs = bb.glob(['source/wrap/source/wrap/**/*.d']),
        imports = ['source/wrap/source', 'source/io/source'],
        compiler_opts = dmd_opts,
        )

if __name__ == '__main__':
    bb.main(targets())
