#!/bin/sh

zig build -Dtarget=x86_64-windows -Drelease-fast
zig build -Dtarget=x86_64-linux   -Drelease-fast

mv zig-out/yabg.exe ./
mv zig-out/yabg     ./
