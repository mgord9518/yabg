# TODO: Finish Makefile
#
# This Makefile is primarily intended for CI
# If you're testing, you should probably just run `zig build`

prefix=zig-out/bin
version=0.0.51

flags=-Doptimize=ReleaseSafe

all: YABG-$(version)-x86_64-win.zip zig-out/bin/yabg

clean:
	rm src/font.psfu
	rm -r zig-out/
	rm YABG-$(version)-x86_64-win.zip

YABG-$(version)-x86_64-win.zip: zig-out/bin/yabg.exe
	zip -r9 YABG-$(version)-x86_64-win.zip zig-out/

zig-out/bin/yabg.exe: src/font.psfu
	zig build -Dtarget=x86_64-windows $(flags)

# TODO: Do not assume Linux host
zig-out/bin/yabg: src/font.psfu
	zig build $(flags)

src/font.psfu:
	txt2psf src/font.txt src/font.psfu

