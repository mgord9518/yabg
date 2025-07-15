{ stdenv, pkgs }: stdenv.mkDerivation rec {
  pname = "yabg";
  version = "0.0.62-alpha";

  src = ../.;

  nativeBuildInputs = with pkgs; [
    zig_0_14.hook
    wayland-scanner
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

  # Add Zig deps
  postUnpack = ''
    ln -s ${pkgs.callPackage ./deps.nix {}} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
}
