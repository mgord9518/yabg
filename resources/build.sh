#!/bin/sh

# Build AppImage
# Variables
[ -z "$TMPDIR" ] && TMPDIR='/tmp'
[ -z "$ARCH" ]   && ARCH=$(uname -m)

# TODO: add CLI flag to obtain version
version=0.2.2
app_id='io.github.mgord9518.yabg'
app_name="YABG"
formatted_name=$(echo $app_name | tr ' ' '_')"-$version-$ARCH"
app_exec="yabg"
temp_dir="$TMPDIR/.buildApp_$formatted_name.$RANDOM"
start_dir="$PWD"

#TODO: create icon for YABG
icon_url='https://raw.githubusercontent.com/AppImage/AppImageKit/master/resources/appimagetool.png'

compression='zstd'

git clone https://github.com/ryupold/raylib.zig --recursive
git clone https://github.com/mgord9518/perlin-zig
git clone https://github.com/mgord9518/basedirs-zig

echo 'building for Windows'
zig build -Dtarget="$ARCH"-windows # -Doptimize=ReleaseSafe

echo 'building for Linux'
zig build -Dcpu="$ARCH" # -Doptimize=ReleaseSafe

strip -s zig-out/bin/*

#TODO: create macOS DMG builds

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

# Define what should be in the desktop entry
entry="[Desktop Entry]
Version=1.0
Type=Application
Name=$app_name
Comment=Yet Another Block Game
Exec=$app_exec
Icon=$app_id
Terminal=true
Categories=Development;Building;
X-AppImage-Version=
[X-App Permissions]
Level=2
Sockets=x11;network
Devices=dri
"

appstream='<?xml version="1.0" encoding="UTF-8"?>
<component type="console-application">
  <id>io.github.mgord9518.yabg</id>
  <name>YABG</name>
  <summary>Yet Another Block Game</summary>
  <metadata_license>FSFAP</metadata_license>
  <project_license>MIT</project_license>
  <description>
    <p>
	An open source building and survival game (WIP)
    </p>
  </description>
  <categories>
    <category></category>
  </categories>
  <provides>
    <binary>yabg</binary>
  </provides>
</component>'

printErr() {
	echo -e "FATAL: $@"
	echo 'Log:'
	cat "$temp_dir/out.log"
	rm "$temp_dir/out.log"
	exit 1
}

if [ ! $? = 0  ]; then
	printErr 'Failed to create temporary directory.'
fi

cd "$temp_dir"
echo "Working directory: $temp_dir"

chmod +x "AppDir/usr/bin/$app_exec"

# Download the icon
wget "$icon_url" -O "AppDir/usr/share/icons/hicolor/scalable/apps/$app_id.svg" &> "$temp_dir/out.log"
if [ ! $? = 0 ]; then
	printErr "Failed to download '$app_id.svg' (make sure you're connected to the internet)"
fi

# Create desktop entry and link up executable and icons
echo "$entry" > "AppDir/$app_id.desktop"
ln -s "./usr/bin/$app_exec" 'AppDir/AppRun'
ln -s "./usr/share/icons/hicolor/scalable/apps/$app_id.svg" "AppDir/$app_id.svg"

wget 'https://raw.githubusercontent.com/mgord9518/appimage_scripts/main/scripts/get_mkappimage.sh'
. ./get_mkappimage.sh

# Use the found mkappimage command to build our AppImage with update information
echo "Building $formatted_name..."
export ARCH="$ARCH"
export VERSION="$version"

# Only build standard AppImage under x86_64 for now as for some reason the aarch64 chroot
# cannot execute the aarch64 version of mkappimage
if [ "$ARCH" = "x86_64" ]; then
	ai_tool --comp="zstd" -u \
		"gh-releases-zsync|mgord9518|yabg|continuous|yabg-*$ARCH.AppImage.zsync" \
		'AppDir/'

	if [ ! $? = 0 ]; then
		printErr "failed to build '$formatted_name'"
	fi
fi

mksquashfs AppDir sfs -root-owned -no-exports -noI -b 1M -comp "$compression" -Xcompression-level 19 -nopad
#mksquashfs AppDir sfs -root-owned -no-exports -noI -b 1M -comp "$compression" -Xhc -nopad
wget "https://github.com/mgord9518/shappimage/releases/download/continuous/runtime-$compression-static-$ARCH" -O runtime

[ $? -ne 0 ] && exit $?

cat runtime sfs > "$formatted_name.shImg"
chmod +x "$formatted_name.shImg"

# Append desktop integration info
wget 'https://raw.githubusercontent.com/mgord9518/shappimage/main/add_integration.sh'
[ $? -ne 0 ] && exit $?
sh add_integration.sh "./$formatted_name.shImg" "AppDir" "gh-releases-zsync|mgord9518|yabg|continuous|yabg-*-$ARCH.shImg.zsync"

# Move completed AppImage and zsync file to start directory
mv "$formatted_name"* "$start_dir"

# Clean up
rm -r "$temp_dir"

exit 0
