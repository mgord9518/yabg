#!/bin/sh

# Build AppImage
# Variables
[ -z "$TMPDIR" ] && TMPDIR='/tmp'
[ -z "$ARCH" ]   && ARCH=$(uname -m)

# TODO: add CLI flag to obtain version
version=0.0.55
app_id='io.github.mgord9518.yabg'
app_name="YABG"
formatted_name=$(echo $app_name | tr ' ' '_')"-$version-$ARCH"
app_exec="yabg"
temp_dir="$TMPDIR/.buildApp_$formatted_name.$RANDOM"
start_dir="$PWD"

echo 'building for Windows'
zig build -Dtarget="$ARCH"-windows --release=safe

echo 'building for Linux'
zig build -Dcpu="$ARCH" --release=safe

strip -s zig-out/bin/*

# Create and move to working directory
mkdir -p "$temp_dir/AppDir/usr/bin" \
         "$temp_dir/AppDir/usr/share/icons/hicolor/scalable/apps"

cp -r 'usr/share/io.github.mgord9518.yabg' "$temp_dir/AppDir/usr/share"

mv zig-out/bin/yabg.exe "$temp_dir/AppDir/usr/bin"

cd "$temp_dir/AppDir"

zip -r9 "$start_dir/$formatted_name-win.zip" "./"*

cd -

rm "$temp_dir/AppDir/usr/bin/yabg.exe"
mv zig-out/bin/yabg "$temp_dir/AppDir/usr/bin"

cd "$temp_dir"
echo "Working directory: $temp_dir"

chmod +x "AppDir/usr/bin/$app_exec"

exit 0
