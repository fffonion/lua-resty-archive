OPENRESTY_PREFIX=/usr/local/openresty

#LUA_VERSION := 5.1
PREFIX ?=          /usr/local
LUA_INCLUDE_DIR ?= $(PREFIX)/include
LUA_LIB_DIR ?=     $(PREFIX)/lib/lua/$(LUA_VERSION)

.PHONY: all test install

all: ;

install: all
	cp -rpv lib/resty/archive/. $(DESTDIR)$(LUA_LIB_DIR)/resty/archive
	cp -pv lib/resty/archive.lua $(DESTDIR)$(LUA_LIB_DIR)/resty/
	
test: all
	PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I../test-nginx/lib -r t


