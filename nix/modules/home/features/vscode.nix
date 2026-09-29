{
  config,
  lib,
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (p: [ p.json5 ]);
  settings =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json"
    else
      "${config.xdg.configHome}/Code/User/settings.json";
  defaults = pkgs.writeText "vscode-initial-settings.json" (
    builtins.toJSON config.features.vscode.initialSettings
  );
in
{
  # A writable seed, intentionally outside programs.vscode's managed settings.
  home.activation.initializeVscode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${python}/bin/python ${../../../assets/helpers}/seed-json-settings.py \
      ${lib.escapeShellArg settings} \
      ${lib.escapeShellArg "${config.xdg.stateHome}/nixconfig/vscode-initialized"} \
      ${defaults}
  '';
}
