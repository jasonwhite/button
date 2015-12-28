local d = require "rules.d.dmd"

d.library {
    name = "foo",
    srcs = {"foo.d"},
    imports = {"src", "tools"},
    combined = false,
}

d.binary {
    name = "bar",
    deps = {"foo"},
    srcs = {"bar.d"},
    combined = false,
}
