#!/bin/sh

git clone https://github.com/Not-Nik/raylib-zig --recurse-submodules
git clone https://github.com/mgord9518/perlin-zig

# Raylib hasn't yet been updated to latest Zig and `addIncludeDir` is now a
# compile error
sed 's/addIncludeDir/addIncludePath/g' -i raylib-zig/raylib/src/build.zig

zig build -Drelease-fast -Dtarget=x86_64-windows # Windows x86_64
zig build -Drelease-fast -Dcpu=x86_64            # Linux x86_64

mv zig-out/bin/yabg* ./

strip -s zig-out/bin/*

#TODO: create Linux AppImage and macOS DMG builds
zip -9    yabg-x86_64-win.zip    yabg.exe resources/
tar -cJvf yabg-x86_64-lin.tar.xz yabg     resources/
