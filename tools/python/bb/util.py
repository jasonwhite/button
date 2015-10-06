# Copyright: Copyright Jason White, 2015
# License:   MIT
# Authors:   Jason White
#
# Description:
# A collection of utility functions.
import os

try:
    finputs  = os.fdopen(int(os.environ['BRILLIANT_BUILD_INPUTS']),  'w')
    foutputs = os.fdopen(int(os.environ['BRILLIANT_BUILD_OUTPUTS']), 'w')

    def add_input(path):
        finputs.write(path)
        finputs.write('\0')
        finputs.flush()

    def add_output(path):
        foutputs.write(path)
        foutputs.write('\0')
        foutputs.flush()
except:
    def add_input(path):
        pass

    def add_output(path):
        pass
