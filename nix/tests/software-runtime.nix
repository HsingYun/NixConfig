{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  # Exercise the real Home Manager wrapper and profile assembly with tiny
  # executables, without building a complete media-player closure.
  testPkgs = pkgs.extend (
    _: _: {
      mpv = lib.makeOverridable (
        {
          scripts ? [ ],
          extraMakeWrapperArgs ? [ ],
        }:
        pkgs.writeShellScriptBin "mpv" ''
          echo ${if scripts == [ ] then "raw" else "configured"}
        ''
      ) { };
    }
  );
  homeFor =
    enabled: extraModules:
    (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = testPkgs;
      modules = [
        ../modules/home/software
        ../modules/home/features/mpv.nix
        {
          home = {
            username = "test";
            homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
            stateVersion = "26.05";
          };
          programs.mpv.enable = enabled;
          software.packageManager = {
            type = "nix";
            externalPkg.packages = [ "mpv" ];
          };
        }
      ]
      ++ extraModules;
    }).config;
  home = homeFor true [ ];
  disabledHome = homeFor false [ ];
  disabledProfile = pkgs.buildEnv {
    name = "software-disabled-wrapper-profile";
    paths = lib.filter (p: lib.getName p == "mpv") disabledHome.home.packages;
  };
  profile = pkgs.buildEnv {
    name = "software-wrapper-profile";
    paths = lib.filter (p: lib.getName p == "mpv") home.home.packages;
  };
  terminfo =
    name:
    pkgs.runCommand name { } ''
      mkdir -p "$out/share/terminfo/g"
      echo ${name} > "$out/share/terminfo/g/ghostty"
    '';
  terminfoCatalog = import ../lib/software/catalog.nix {
    pkgs = pkgs // {
      ncurses = terminfo "generic-ncurses";
      ghostty = terminfo "terminal-ghostty";
    };
  };
  terminfoSelection = import ../lib/software/resolve.nix { inherit lib; } {
    catalog = { inherit (terminfoCatalog) ncurses ghostty maple-mono; };
    requirements = {
      ncurses = { };
      ghostty = { };
    };
    packageManager = "nix";
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "nixos";
  };
  terminfoProfile = pkgs.buildEnv {
    name = "terminal-and-generic-terminfo-profile";
    paths = lib.concatMap (name: terminfoSelection.resolved.${name}.packages) [
      "ncurses"
      "ghostty"
    ];
  };
  # Model an old native executable that remains installed after switching
  # provider. It must not mask the feature's configured executable.
  staleNative = pkgs.writeShellScriptBin "mpv" "echo stale-native";
  # A standard user package override must win in both buildEnv and the shell.
  preferredMpv = lib.hiPrio (pkgs.writeShellScriptBin "mpv" "echo user-override");
  overriddenHome = homeFor true [
    {
      home.packages = [ preferredMpv ];
      software = {
        packageManager = lib.mkForce (if pkgs.stdenv.hostPlatform.isDarwin then "homebrew" else "nix");
        packageOverrides.mpv = testPkgs.mpv;
      };
    }
  ];
  overrideProfile = pkgs.buildEnv {
    name = "upstream-priority-profile";
    paths = lib.filter (p: lib.getName p == "mpv") overriddenHome.home.packages;
  };
  # Run the upstream-generated environment hook, mapping only the installed
  # profile/native prefix into the sandbox. No handcrafted PATH algorithm.
  sessionVars = pkgs.runCommand "review-session-vars" { } ''
    substitute ${overriddenHome.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh "$out" \
      --replace-warn ${lib.escapeShellArg overriddenHome.home.profileDirectory} ${overrideProfile} \
      ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "--replace-fail ${overriddenHome.software.nativePrefix} ${staleNative}"}
  '';
  compiler =
    name:
    lib.setPrio 10 (
      pkgs.runCommand name { } ''
        mkdir -p "$out/bin"
        for command in cc c++ ${name}; do
          printf '#!${pkgs.runtimeShell}\necho ${name}\n' > "$out/bin/$command"
          chmod +x "$out/bin/$command"
        done
      ''
    );
  compilerPlan = import ../lib/software/resolve.nix { inherit lib; } {
    pkgs = pkgs // {
      gcc = compiler "gcc";
    };
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
    packageManager = {
      type = "nix";
      externalPkg.packages = [ "gcc" ];
    };
    catalog.clang.nix.package = compiler "clang";
    requirements.clang = { };
  };
  compilerProfile = pkgs.buildEnv {
    name = "software-compiler-profile";
    paths = compilerPlan.installations.nix.homePackages;
  };
  compilerPkgs = pkgs // {
    gcc = compiler "gcc";
    llvmPackages = pkgs.llvmPackages // {
      clang = compiler "clang";
    };
  };
  develProfiles = import ../lib/software/profiles.nix { pkgs = compilerPkgs; };
  develCompilerPlan = import ../lib/software/resolve.nix { inherit lib; } {
    catalog = { inherit (develProfiles.devel) gcc clang; };
    requirements = {
      gcc = { };
      clang = { };
    };
    packageManager = "nix";
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
  };
  develCompilerProfile = pkgs.buildEnv {
    name = "devel-compilers-profile";
    paths = develCompilerPlan.installations.nix.homePackages;
  };
  prioritySelection = import ../lib/software/resolve.nix { inherit lib; } {
    pkgs = compilerPkgs;
    catalog = { inherit (develProfiles.devel) gcc clang; };
    requirements = {
      gcc = { };
      clang = { };
    };
    packageOverrides.gcc = lib.hiPrio compilerPkgs.gcc;
    packageManager = "nix";
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
  };
  priorityPlan = import ../lib/software/materialize.nix { inherit lib; } {
    selection = prioritySelection;
  };
  priorityProfile = pkgs.buildEnv {
    name = "overridden-compiler-profile";
    paths = priorityPlan.installations.nix.homePackages;
  };
  # A module wrapper can change the input package's priority. Extras must be
  # demoted against that final package, not just against the original input.
  wrappedPlan = import ../lib/software/materialize.nix { inherit lib; } {
    selection = import ../lib/software/resolve.nix { inherit lib; } {
      pkgs = compilerPkgs;
      catalog.clang.nix.package = compilerPkgs.llvmPackages.clang;
      requirements.clang.installNix = false;
      packageManager = {
        type = "nix";
        externalPkg.packages = [ "gcc" ];
      };
      platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
    };
    runtimePackages.clang = lib.setPrio 40 (compiler "wrapped-clang");
  };
  wrappedProfile = pkgs.buildEnv {
    name = "wrapped-compiler-profile";
    paths = wrappedPlan.installations.nix.homePackages ++ wrappedPlan.installations.nix.modulePackages;
  };
  llvmStub =
    label:
    pkgs.runCommand "llvm-${label}"
      {
        outputs = [
          "out"
          "dev"
        ];
        meta.outputsToInstall = [ "out" ];
      }
      ''
        mkdir -p "$out/bin" "$dev/bin"
        printf '#!${pkgs.runtimeShell}\necho ${label}\n' > "$out/bin/llvm-tool"
        printf '#!${pkgs.runtimeShell}\necho ${label}\n' > "$dev/bin/llvm-config"
        chmod +x "$out/bin/llvm-tool" "$dev/bin/llvm-config"
      '';
  outputPlan = import ../lib/software/materialize.nix { inherit lib; } {
    selection = import ../lib/software/resolve.nix { inherit lib; } {
      inherit pkgs;
      catalog.llvm.nix = {
        package = llvmStub "original";
        outputs = [
          "out"
          "dev"
        ];
      };
      requirements.llvm = { };
      packageOverrides.llvm = llvmStub "replacement";
      packageManager = "nix";
      platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
    };
  };
  outputProfile = pkgs.buildEnv {
    name = "overridden-outputs-profile";
    paths = outputPlan.installations.nix.homePackages;
  };
in
pkgs.runCommand "software-runtime-check" { } ''
  test -z ${lib.escapeShellArg (lib.concatStringsSep ":" home.software.plan.binPaths)}
  (
    export PATH=${overrideProfile}/bin:${staleNative}/bin:$PATH
    unset __HM_SESS_VARS_SOURCED
    . ${sessionVars}
    test "$(mpv)" = user-override
    test "$(${overrideProfile}/bin/mpv)" = "$(mpv)"
  )
  test "$(cat ${terminfoProfile}/share/terminfo/g/ghostty)" = terminal-ghostty
  test "$(${disabledProfile}/bin/mpv)" = raw
  (
    export PATH=${disabledProfile}/bin:$PATH
    test "$(mpv)" = raw
  )
  test "$(${profile}/bin/mpv)" = configured
  export PATH=${profile}/bin:${staleNative}/bin:$PATH
  test "$(mpv)" = configured
  test "$(command -v mpv)" = ${profile}/bin/mpv
  test "$(${home.software.resolved.mpv.command "mpv"})" = configured
  test "$(${compilerProfile}/bin/cc)" = clang
  test "$(${compilerProfile}/bin/c++)" = clang
  test "$(${compilerProfile}/bin/gcc)" = gcc
  test "$(${develCompilerProfile}/bin/cc)" = clang
  test "$(${develCompilerProfile}/bin/c++)" = clang
  test "$(${develCompilerProfile}/bin/gcc)" = gcc
  (
    export PATH=${outputProfile}/bin:$PATH
    test "$(llvm-tool)" = replacement
    test "$(llvm-config)" = replacement
    test "$(${outputProfile}/bin/llvm-config)" = "$(llvm-config)"
  )
  (
    export PATH=${priorityProfile}/bin:$PATH
    test "$(cc)" = gcc
    test "$(${priorityProfile}/bin/cc)" = "$(cc)"
  )
  (
    export PATH=${wrappedProfile}/bin:$PATH
    test "$(cc)" = wrapped-clang
    test "$(${wrappedProfile}/bin/cc)" = "$(cc)"
    test "$(gcc)" = gcc
  )
  touch "$out"
''
