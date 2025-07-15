# This Makefile is primarily intended for CI
# If you're testing, you should probably just run `zig build`

prefix  = zig-out
version = $(shell cat build.zig.zon | grep '.version' | cut -d'"' -f2)
arch    = x86_64

ZIGFLAGS = --release=safe

all: YABG-$(version)-$(arch).zip

clean:
	rm -r $(prefix)
	rm YABG-$(version)-$(arch).zip

YABG-$(version)-$(arch).zip: $(prefix)/bin/yabg.exe $(prefix)/bin/yabg
	cd $(prefix); zip -r9 ../YABG-$(version)-$(arch).zip ./

$(prefix)/bin/yabg.exe: build.zig lib/engine/fonts/5x8.psfu
	zig build -Dtarget=$(arch)-windows $(ZIGFLAGS) -p $(prefix)

# TODO: Do not assume Linux host
$(prefix)/bin/yabg: build.zig lib/engine/fonts/5x8.psfu
	zig build $(ZIGFLAGS) -p $(prefix)
	strip -s $(prefix)/bin/yabg

lib/engine/fonts/5x8.psfu: build.zig lib/engine/fonts/5x8.txt
	zig build font
