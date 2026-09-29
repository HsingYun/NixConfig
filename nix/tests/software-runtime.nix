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
    enabled:
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
      ];
    }).config;
  home = homeFor true;
  disabledHome = homeFor false;
  disabledProfile = pkgs.buildEnv {
    name = "software-disabled-wrapper-profile";
    paths = lib.filter (p: lib.getName p == "mpv") disabledHome.home.packages;
  };
  profile = pkgs.buildEnv {
    name = "software-wrapper-profile";
    paths = lib.filter (p: lib.getName p == "mpv") home.home.packages;
  };
  # Model an old native executable that remains installed after switching
  # provider. It must not mask the feature's configured executable.
  staleNative = pkgs.writeShellScriptBin "mpv" "echo stale-native";
  disabledRuntimePaths = lib.filter (
    path: lib.hasInfix "-mpv/bin" path
  ) disabledHome.home.sessionPath;
  runtimePaths = lib.filter (path: lib.hasInfix "-mpv/bin" path) home.home.sessionPath;
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
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
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
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
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
    platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
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
      platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
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
      platform = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
    };
  };
  outputProfile = pkgs.buildEnv {
    name = "overridden-outputs-profile";
    paths = outputPlan.installations.nix.homePackages;
  };
in
pkgs.runCommand "software-runtime-check" { } ''
  test "$(${disabledProfile}/bin/mpv)" = raw
  (
    export PATH=${lib.escapeShellArg (lib.concatStringsSep ":" disabledRuntimePaths)}:$PATH
    test "$(mpv)" = raw
  )
  test "$(${profile}/bin/mpv)" = configured
  export PATH=${lib.escapeShellArg (lib.concatStringsSep ":" runtimePaths)}:${staleNative}/bin:$PATH
  test "$(mpv)" = configured
  test "$(command -v mpv)" = ${home.programs.mpv.finalPackage}/bin/mpv
  test "$(${home.software.resolved.mpv.command "mpv"})" = configured
  test "$(${compilerProfile}/bin/cc)" = clang
  test "$(${compilerProfile}/bin/c++)" = clang
  test "$(${compilerProfile}/bin/gcc)" = gcc
  test "$(${develCompilerProfile}/bin/cc)" = clang
  test "$(${develCompilerProfile}/bin/c++)" = clang
  test "$(${develCompilerProfile}/bin/gcc)" = gcc
  (
    export PATH=${lib.escapeShellArg (lib.concatStringsSep ":" outputPlan.binPaths)}:$PATH
    test "$(llvm-tool)" = replacement
    test "$(llvm-config)" = replacement
    test "$(${outputProfile}/bin/llvm-config)" = "$(llvm-config)"
  )
  (
    export PATH=${lib.escapeShellArg (lib.concatStringsSep ":" priorityPlan.binPaths)}:$PATH
    test "$(cc)" = gcc
    test "$(${priorityProfile}/bin/cc)" = "$(cc)"
  )
  (
    export PATH=${lib.escapeShellArg (lib.concatStringsSep ":" wrappedPlan.binPaths)}:$PATH
    test "$(cc)" = wrapped-clang
    test "$(${wrappedProfile}/bin/cc)" = "$(cc)"
    test "$(gcc)" = gcc
  )
  touch "$out"
''
