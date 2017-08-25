CFLAGS=-g -Wall -Werror -std=c11 $(shell pkg-config swipl --cflags) $(shell pkg-config sdl2 --cflags)
LDFLAGS=$(shell pkg-config sdl2 --libs)

all: sdl

sdl: sdl.pl sdl.so
	swipl -O --goal=main --stand_alone=true -o sdl -c sdl.pl

sdl.so: sdl.o
	swipl-ld -shared -o $@ $(LDFLAGS) -ld clang $< 

sdl.o: sdl.c
	clang -o $@ $(CFLAGS) -c -fPIC $<

clean:
	rm -f sdl *.so *.o

.PHONY: clean all
