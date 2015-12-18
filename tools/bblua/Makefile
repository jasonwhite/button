.PHONY: all clean

SOURCES=$(wildcard src/*.cc)
OBJECTS=$(addsuffix .o, $(SOURCES))

TARGET=bblua

INCLUDE_PATHS=-Icontrib/lua/include
LIB_PATHS=-Lcontrib/lua/lib

CXXFLAGS=-g -Wall -Werror

all: $(TARGET)

%.cc.o: %.cc
	${CXX} $(CXXFLAGS) $(INCLUDE_PATHS) -c $^ -o $@

$(TARGET): $(OBJECTS) contrib/lua/lib/liblua.a
	${CXX} $(OBJECTS) $(LIB_PATHS) -ldl -llua -o $@

contrib/lua/lib/liblua.a:
	./contrib/lua.sh

clean:
	$(RM) $(TARGET) $(OBJECTS)
