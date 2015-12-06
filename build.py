#!/bin/env python3
# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# Generates the rules necessary to build Brilliant Build.

import bb

from glob import glob
from itertools import chain

def parse_args():
    """Parses arguments for the application."""
    import argparse

    parser = argparse.ArgumentParser(
            description='Generates the rules for building Brilliant Build.')
    parser.add_argument('output',
            type=argparse.FileType('w'),
            help='Path to the file to output the rules to')
    return parser.parse_args()

# Wrap all commands with the bootstrapped wrapper.
bb.core.Target.wrapper = ['./bb-wrap-bootstrap']

def targets():

    dmd_opts = ['-Isource/io/source', '-release', '-O', '-w']

    yield bb.dmd.Library(
        name = 'io',
        srcs = glob('source/io/source/io/**/*.d', recursive=True),
        compiler_opts = dmd_opts,
        )

    yield bb.dmd.Binary(
        name = 'bb',
        deps = ['io'],
        srcs = glob('source/util/*.d') + \
               glob('source/bb/**/*.d', recursive=True) + \
               glob('source/darg/source/*.d'),
        compiler_opts = ['-Isource', '-Isource/darg/source'] + dmd_opts,
        linker_opts = ['-L-lsqlite3'],
        )

    yield bb.dmd.Binary(
        name = 'bb-wrap',
        deps = ['io'],
        srcs = glob('source/wrap/source/wrap/**/*.d', recursive=True),
        compiler_opts = ['-Isource/wrap/source'] + dmd_opts,
        )

if __name__ == '__main__':
    args = parse_args()
    try:
        bb.dump(targets(), f=args.output, indent=4)
    except bb.TargetError as e:
        print('Error:', e, file=sys.stderr)
