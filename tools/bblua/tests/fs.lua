
assert(fs.globmatch("", ""))
assert(fs.globmatch("", "*"))
assert(fs.globmatch("foo", "foo"))
assert(fs.globmatch("foo.c", "*.c"))
assert(fs.globmatch("foo", "foo*"))
assert(fs.globmatch("foo.bar.baz", "*.*.*"))
assert(fs.globmatch("foo.bar.baz", "f*.b*.b*"))
assert(fs.globmatch("foo", "[bf]oo"))
assert(fs.globmatch("zoo", "[!bf]oo"))
assert(fs.globmatch("foo.c", "[fb]*.c"))

assert(not fs.globmatch("", "a"))
assert(not fs.globmatch("a", ""))
assert(not fs.globmatch("foo", "bar"))
assert(not fs.globmatch("foo.bar", "foo"))
assert(not fs.globmatch("foo.d", "*.c"))
assert(not fs.globmatch("foo.bar.baz", "f*.f*.f*"))
assert(not fs.globmatch("zoo", "[bf]oo"))
assert(not fs.globmatch("zoo", "[!bzf]oo"))

assert(fs.getcwd())

table.print(fs.glob("*/*.cc"))
