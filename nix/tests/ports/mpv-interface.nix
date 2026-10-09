# One public input suite, exercised against original HM, delegated Nix and native
# implementations. Observe user inputs and generated files, not lowering details.
{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  platforms = {
    arch = {
      system = "x86_64-linux";
      manager = "pacman";
      homeDirectory = "/home/test";
    };
    darwin = {
      system = "aarch64-darwin";
      manager = "homebrew";
      homeDirectory = "/Users/test";
    };
  };
  emptySettings = {
    programs.mpv = {
      config = lib.mkForce { };
      profiles = lib.mkForce { };
      defaultProfiles = lib.mkForce [ ];
      includes = lib.mkForce [ ];
      bindings = lib.mkForce { };
    };
  };
  cases = {
    absent = [ ];
    onlyScripts = [ emptySettings ];
    entirelyEmpty = [
      emptySettings
      { programs.mpv.scripts = lib.mkForce [ ]; }
    ];
    scalar = [ { programs.mpv.config.script = "/custom path/player.lua"; } ];
    list = [
      {
        programs.mpv.config.script = [
          "/custom/first.lua"
          "/custom/second.lua"
        ];
      }
    ];
    scalarDefault = [
      { programs.mpv.config.script = lib.mkDefault "/default.lua"; }
      { programs.mpv.config.script = "/selected.lua"; }
    ];
    listOrder = [
      { programs.mpv.config.script = [ "/middle.lua" ]; }
      { programs.mpv.config.script = lib.mkBefore [ "/first.lua" ]; }
      { programs.mpv.config.script = lib.mkAfter [ "/last.lua" ]; }
    ];
    forceEmptyConfigScripts = [
      { programs.mpv.config.script = [ "/discarded.lua" ]; }
      { programs.mpv.config.script = lib.mkForce [ ]; }
    ];
    forceEmptyConfig = [ { programs.mpv.config = lib.mkForce { }; } ];
    forceEmptyScripts = [
      { programs.mpv.config.script = "/keep-user-script.lua"; }
      { programs.mpv.scripts = lib.mkForce [ ]; }
    ];
    disabled = [
      { programs.mpv.enable = false; }
      { programs.mpv.config.script = "/inactive.lua"; }
    ];
  }
  // builtins.listToAttrs (
    map
      (args: {
        name = "rendering-${if args.config then "config" else "no-config"}-${
          if args.profiles then "profiles" else "no-profiles"
        }-${if args.defaults then "defaults" else "no-defaults"}";
        value = [
          {
            programs.mpv = {
              config = lib.mkForce (lib.optionalAttrs args.config { hwdec = "auto"; });
              profiles = lib.mkForce (lib.optionalAttrs args.profiles { review.hwdec = "auto-safe"; });
              defaultProfiles = lib.mkForce (lib.optional args.defaults "review");
            };
          }
        ];
      })
      (
        lib.cartesianProduct {
          config = [
            false
            true
          ];
          profiles = [
            false
            true
          ];
          defaults = [
            false
            true
          ];
        }
      )
  );
  checkPlatform =
    platform: spec:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${spec.system};
      script =
        (pkgs.runCommand "mpv-interface-script" { } ''
          mkdir -p "$out/share/mpv/scripts"
          echo '-- main' > "$out/share/mpv/scripts/main.lua"
          echo '-- helper' > "$out/share/mpv/scripts/helper.lua"
        '')
        // {
          scriptName = "main.lua";
          extraScriptsToLoad = [ "helper.lua" ];
        };
      managedPaths = [
        "${script}/share/mpv/scripts/main.lua"
        "${script}/share/mpv/scripts/helper.lua"
      ];
      make =
        backend: modules:
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };
          modules = [
            {
              home = {
                username = "test";
                inherit (spec) homeDirectory;
                stateVersion = "26.05";
              };
              programs.mpv = {
                enable = lib.mkDefault true;
                scripts = [ script ];
                config.hwdec = "auto";
                profiles.review.hwdec = "auto-safe";
                defaultProfiles = [ "review" ];
                includes = [ "/custom/settings.conf" ];
                bindings.SPACE = "cycle pause";
              };
            }
          ]
          ++ lib.optionals (backend != "upstream") [
            ../../modules/home/software
            ../../ports/common/home/capabilities/mpv.nix
            {
              software = {
                inherit platform;
                packageManager = if backend == "native" then spec.manager else "nix";
              };
            }
          ]
          ++ modules;
        }).config;
      fileText = cfg: cfg.xdg.configFile."mpv/mpv.conf".text or "";
      lines =
        text: lib.filter (line: builtins.match "[[:space:]]*" line == null) (lib.splitString "\n" text);
      # MPV's length-prefixed values are observed at the rendered file boundary.
      scriptLine = path: "script=%${toString (builtins.stringLength path)}%${path}";
      files =
        cfg:
        lib.mapAttrs (_: file: file.text) (
          lib.filterAttrs (name: _: lib.hasPrefix "mpv/" name) cfg.xdg.configFile
        );
      public = cfg: {
        inherit (cfg.programs.mpv)
          enable
          config
          profiles
          defaultProfiles
          includes
          bindings
          ;
        scripts = map toString cfg.programs.mpv.scripts;
      };
    in
    lib.mapAttrs (
      name: modules:
      let
        upstream = make "upstream" modules;
        delegated = make "nix" modules;
        native = make "native" modules;
        active = upstream.programs.mpv.enable;
        expectedPaths = lib.optionals (active && upstream.programs.mpv.scripts != [ ]) managedPaths;
        nativeLines = lines (fileText native);
        generatedLines = map scriptLine expectedPaths;
        visibleLines = lib.filter (line: !(builtins.elem line generatedLines)) nativeLines;
        valid = cfg: lib.all (a: a.assertion) cfg.assertions;
        label = "MPV public interface (${platform}/${name}): ";
      in
      assert lib.assertMsg (lib.all valid [
        upstream
        delegated
        native
      ]) (label + "invalid configuration");
      assert lib.assertMsg (public native == public upstream && public delegated == public upstream) (
        label + "implementation changed public input semantics"
      );
      assert lib.assertMsg (files delegated == files upstream) (label + "Nix files differ from upstream");
      assert lib.assertMsg (
        !active || delegated.programs.mpv.finalPackage.drvPath == upstream.programs.mpv.finalPackage.drvPath
      ) (label + "Nix wrapper differs from upstream");
      assert lib.assertMsg (lib.all (
        line: lib.count (actual: actual == line) nativeLines == 1
      ) generatedLines) (label + "native implementation lost or duplicated a declared script");
      assert lib.assertMsg (lib.take (builtins.length generatedLines) nativeLines == generatedLines) (
        label + "managed scripts must load globally before user profile sections"
      );
      assert lib.assertMsg (visibleLines == lines (fileText upstream)) (
        label + "native implementation changed user-rendered configuration"
      );
      assert lib.assertMsg (!active || native.programs.mpv.package == null) (
        label + "supported input unexpectedly selected Nix"
      );
      assert lib.assertMsg (expectedPaths != [ ] || files native == files upstream) (
        label + "without managed scripts native files differ from upstream"
      );
      true
    ) cases;
in
lib.mapAttrs checkPlatform platforms
