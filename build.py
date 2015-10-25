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


compiler_flags=['-Isource/io/source', '-release', '-w']

io_sources = glob('source/io/source/io/**/*.d', recursive=True)

io_rules = bb.dmd.static_library(
        path = 'io',
        sources = io_sources,
        compiler_flags = compiler_flags,
        )

bb_sources = glob('source/*.d') + \
             glob('source/util/*.d') + \
             glob('source/bb/**/*.d', recursive=True)

bb_rules = bb.dmd.binary(
        path = 'bb',
        sources = bb_sources,
        libraries = ['io'],
        compiler_flags = ['-Isource'] + compiler_flags,
        linker_flags = ['-L-lsqlite3']
        )

rules = chain(io_rules, bb_rules)

if __name__ == '__main__':
    args = parse_args()
    bb.dump(rules, f=args.output, indent=4)
