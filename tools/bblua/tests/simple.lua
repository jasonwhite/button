rule {
    inputs = {"foo.c", "foo.h"},
    outputs = {"foo.o"},
    task = {"gcc", "-c", "foo.c", "-o", "foo.o"},
}

rule {
    inputs = {"bar.c", "foo.h"},
    outputs = {"bar.o"},
    task = {"gcc", "-c", "bar.c", "-o", "bar.o"},
}

rule {
    inputs = {"foo.o", "bar.o"},
    outputs = {"foobar"},
    task = {"gcc", "foo.o", "bar.o", "-o", "foobar"},
}
