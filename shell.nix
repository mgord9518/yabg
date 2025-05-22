{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    zig_0_14
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXi
    libGL
    libxkbcommon
    pulseaudio
    p7zip
    wayland
    wayland-scanner
    zip

    libdrm
    libgbm

    psftools
  ];
}
