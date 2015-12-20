.PHONY: all clean

SOURCES=$(wildcard src/*.cc)
OBJECTS=$(addsuffix .o, $(SOURCES))

LUA_SCRIPTS=$(shell find scripts -type f -name '*.lua')
LUA_SCRIPTS_C=$(patsubst scripts/%.lua, src/embedded/%.c, $(LUA_SCRIPTS))

TARGET=bblua

INCLUDE_PATHS=-Icontrib/lua/include
LIB_PATHS=-Lcontrib/lua/lib

CXXFLAGS=-g -Wall -Werror

all: $(TARGET)

%.cc.o: %.cc
	${CXX} $(CXXFLAGS) $(INCLUDE_PATHS) -c $< -o $@

# Generate strings from Lua files.
src/embedded/%.c: scripts/%.lua
	@mkdir -p "$(@D)"
	xxd -i $^ $@

src/embedded.cc.o: $(LUA_SCRIPTS_C)

$(TARGET): $(OBJECTS) contrib/lua/lib/liblua.a
	${CXX} $(OBJECTS) $(LIB_PATHS) -ldl -llua -o $@

contrib/lua/lib/liblua.a:
	./contrib/lua.sh

clean:
	$(RM) $(TARGET) $(OBJECTS) $(LUA_SCRIPTS_C)
