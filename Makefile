all: src/font.psfu

prefix=zig-out/bin

clean:
	rm src/font.psfu

src/font.psfu:
	txt2psf src/font.txt src/font.psfu

