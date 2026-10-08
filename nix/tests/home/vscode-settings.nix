{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  home =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../../modules/home/software
        ../../modules/shared/features.nix
        ../../modules/home/features/vscode.nix
        {
          home = {
            username = "test";
            homeDirectory = "/test-home";
            stateVersion = "26.05";
          };
          software.packageManager = if pkgs.stdenv.hostPlatform.isDarwin then "homebrew" else "pacman";
          features.vscode.settings = {
            "editor.fontFamily" = "Managed font";
            "[nix]"."editor.tabSize" = 2;
            "editor.rulers" = [ 80 ];
          };
        }
      ];
    }).config;
  activate = pkgs.writeShellScript "vscode-settings-activation" (
    ''
      set -euo pipefail
      run() { "$@"; }
      verboseEcho() { :; }
      errorEcho() { echo "$@" >&2; }
    ''
    +
      lib.replaceStrings [ "/test-home" ] [ "test-home" ]
        home.home.activation.vscodeMutableUserSettings.data
  );
  settings =
    "test-home/"
    + (
      if pkgs.stdenv.hostPlatform.isDarwin then
        "Library/Application Support/Code/User/settings.json"
      else
        ".config/Code/User/settings.json"
    );
in
assert home.programs.vscode.package == null;
assert home.programs.vscode.profiles.default.mutableUserSettings;
assert !(home.home.file ? "/${settings}");
pkgs.runCommand "vscode-mutable-settings-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
  }
  ''
    settings=${lib.escapeShellArg settings}
    mkdir -p "$(dirname "$settings")"
    cat > "$settings" <<'JSON'
    {
      // User edits coexist with declarations.
      "editor.fontFamily": "User font",
      "editor.fontSize": 18,
      "[nix]": { "editor.tabSize": 8, "editor.wordWrap": "on" },
      "editor.rulers": [100, 120],
    }
    JSON
    chmod 600 "$settings"
    ${activate}
    test -f "$settings" && test ! -L "$settings" && test -w "$settings"
    jq -e '."editor.fontFamily" == "Managed font" and ."editor.fontSize" == 18 and ."[nix]"."editor.tabSize" == 2 and ."[nix]"."editor.wordWrap" == "on" and ."editor.rulers" == [80]' "$settings"
    jq '."editor.fontFamily" = "Another font" | ."editor.fontSize" = 22' "$settings" > edited
    cat edited > "$settings"
    ${activate}
    jq -e '."editor.fontFamily" == "Managed font" and ."editor.fontSize" == 22' "$settings"
    cp "$settings" expected
    DRY_RUN=1 ${activate}
    cmp "$settings" expected
    echo '{ broken' > "$settings"
    cp "$settings" invalid
    if ${activate}; then
      echo 'Invalid settings should fail without overwriting' >&2
      exit 1
    fi
    cmp "$settings" invalid
    rm "$settings"
    ${activate}
    jq -e '."editor.fontFamily" == "Managed font"' "$settings"
    touch "$out"
  ''
