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
    SDL2
    pkg-config
    libdrm
    libgbm

    psftools
  ];
    shellHook = ''
        export LD_LIBRARY_PATH=${pkgs.libdrm}/lib:$LD_LIBRARY_PATH
        export PKG_CONFIG_PATH=${pkgs.libdrm}/lib/pkgconfig:$PKG_CONFIG_PATH
        pkg-config --cflags --libs libdrm
        '';
}
