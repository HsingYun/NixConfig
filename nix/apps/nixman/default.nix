{ pkgs, homeManager }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "nixman";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p "$out/lib/nixman" "$out/bin"
    cp -r nixman templates "$out/lib/nixman/"
    makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/nixman" \
      --add-flags '-m nixman' \
      --prefix PYTHONPATH : "$out/lib/nixman" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.nix
          homeManager
        ]
      }
  '';
  meta = {
    description = "Preview updates and manage upstream Nix system and home generations";
    mainProgram = "nixman";
    platforms = pkgs.lib.platforms.unix;
    license = pkgs.lib.licenses.asl20;
  };
}
