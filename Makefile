# TODO: Finish Makefile
#
# This Makefile is primarily intended for CI
# If you're testing, you should probably just run `zig build`

prefix  = zig-out
version = 0.0.60

ZIGFLAGS = --release=safe

all: YABG-$(version)-x86_64.zip

clean:
	rm -r $(prefix)
	rm YABG-$(version)-x86_64.zip

YABG-$(version)-x86_64.zip: $(prefix)/bin/yabg.exe $(prefix)/bin/yabg
	cd $(prefix); zip -r9 ../YABG-$(version)-x86_64.zip ./

zig-out/bin/yabg.exe: build.zig lib/engine/fonts/font.psfu
	zig build -Dtarget=x86_64-windows $(ZIGFLAGS)

# TODO: Do not assume Linux host
zig-out/bin/yabg: build.zig lib/engine/fonts/font.psfu
	zig build $(ZIGFLAGS)
	strip -s $(prefix)/bin/yabg

lib/engine/fonts/font.psfu: build.zig lib/engine/fonts/font.txt
	zig build font

