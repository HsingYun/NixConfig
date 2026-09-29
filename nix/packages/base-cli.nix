{ pkgs }:

with pkgs;
lib.optionals (!stdenv.hostPlatform.isDarwin) [ vim ]
++ [
  nano
  wget
  curl
]
