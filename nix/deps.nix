{ linkFarm, fetchFromGitHub }:

linkFarm "zig-packages" [
  {
    name = "raylib-5.5.0-whq8uOWoOgR5-m0pw6s5YQ8v_BbPUilDSRLpzziy5JVh";
    path = fetchFromGitHub {
      owner  = "raysan5";
      repo   = "raylib";
      rev    = "e00c5eb8b1068b1fb3c1c52fc00967749f2a990a";
      sha256 = "sha256-1sOfeg1vT0eKicLcB75x8T+id/LFyskPWhV0J87U5PM=";
    };
  }
  {
    name = "known_folders-0.0.0-Fy-PJtLDAADGDOwYwMkVydMSTp_aN-nfjCZw6qPQ2ECL";
    path = fetchFromGitHub {
      owner  = "ziglibs";
      repo   = "known-folders";
      rev    = "aa24df42183ad415d10bc0a33e6238c437fc0f59";
      sha256 = "sha256-YiJ2lfG1xsGFMO6flk/BMhCqJ3kB3MnOX5fnfDEcmMY=";
    };
  }
  {
    name = "perlin-0.1.1-hiqlWGcZAABIllyOKMo6AM9TRX19iq_k6joT3fvRCFja";
    path = fetchFromGitHub {
      owner  = "mgord9518";
      repo   = "perlin-zig";
      rev    = "ccf62ddcbde9fd3b1572c5385e15062c72201f0a";
      sha256 = "sha256-L+XeROnS+diJV7ckQlFtc1ku9pl3SZTlebH//oNE0zY=";
    };
  }
]
