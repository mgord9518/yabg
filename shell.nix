{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXi
    libGL
    libxkbcommon
    pulseaudio
    p7zip
    #wayland

    psftools
  ];
}
