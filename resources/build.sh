#!/bin/sh

git clone https://github.com/Not-Nik/raylib-zig --recurse-submodules
git clone https://github.com/mgord9518/perlin-zig

# Raylib hasn't yet been updated to latest Zig
sed 's/addIncludeDir/addIncludePath/g' -i raylib-zig/raylib/src/build.zig

zig build -Drelease-fast -Dtarget=x86_64-windows
zig build -Drelease-fast

mv zig-out/bin/yabg.exe ./
mv zig-out/bin/yabg     ./

zip -9 yabg-x86_64-win.zip yabg.exe resources
tar -cJvf yabg-x86_64-lin.zip yabg resources
