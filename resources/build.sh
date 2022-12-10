#!/bin/sh

git clone https://github.com/Not-Nik/raylib-zig --recurse-submodules
git clone https://github.com/mgord9518/perlin-zig

sed 's/addIncludeDir/addIncludePath/g' -i raylib-zig/raylib/src/build.zig

zig build -Drelease-fast -Dtarget=x86_64-windows
zig build -Drelease-fast

mv zig-out/bin/yabg.exe ./
mv zig-out/bin/yabg     ./
