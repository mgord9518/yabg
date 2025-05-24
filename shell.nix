{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    zig_0_14
    wayland-scanner
    zip
    psftools
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXi
    libGL
    libxkbcommon
    pulseaudio
    wayland
  ];

  LD_LIBRARY_PATH = with pkgs; pkgs.lib.makeLibraryPath [
    libdecor
  ];
}
