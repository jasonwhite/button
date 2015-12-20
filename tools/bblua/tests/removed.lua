-- These functions can all affect the file system and are thus disabled.
assert(io.popen == nil)
assert(io.tmpfile == nil)

assert(os.execute == nil)
assert(os.tmpname == nil)
assert(os.rename == nil)
assert(os.remove == nil)

assert(#package.searchers == 3)
