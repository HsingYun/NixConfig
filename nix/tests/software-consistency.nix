{
  inputs,
  mkHost,
  allOff,
  ownershipHost,
}:
let
  inherit (inputs.nixpkgs) lib;
  sameLlvm =
    ownershipHost
      {
        type = "nix";
        externalPkg.packages = [ "llvmPackages.llvm.dev" ];
      }
      { devel = true; }
      (
        { pkgs, ... }: {
          software.packageOverrides.llvm = pkgs.llvmPackages.llvm;
        }
      );
  changedLlvm = ownershipHost "nix" { devel = true; } (
    { lib, pkgs, ... }: {
      software.packageOverrides.llvm = lib.hiPrio (
        pkgs.llvmPackages.llvm.overrideAttrs (_: {
          pname = "custom-llvm";
        })
      );
    }
  );
  missingOutput = ownershipHost "nix" { devel = true; } (
    { pkgs, ... }: {
      software.packageOverrides.llvm = pkgs.hello;
    }
  );
  disabledMpv = ownershipHost "nix" { mpv = true; } (
    { pkgs, ... }: {
      programs.mpv.enable = false;
      # An inactive adapter must not force or validate its package options.
      programs.mpv.package = pkgs.hello;
    }
  );
  disabledExtra =
    manager:
    let
      isDarwin = manager == "homebrew";
      configuration =
        (mkHost "DisabledExtraTest" {
          platform = if isDarwin then "darwin" else "arch";
          packageManager = {
            type = manager;
            externalPkg.${if isDarwin then "brews" else "packages"} = [ "mpv" ];
          };
          features = allOff // {
            mpv = true;
          };
          systemConfig = if isDarwin then { system.stateVersion = 6; } else null;
          homeConfig = { pkgs, ... }: {
            home.stateVersion = "26.05";
            programs.mpv.enable = false;
            # An inactive override must not replace the explicit native/Nix extra.
            software.packageOverrides.mpv = pkgs.hello;
          };
        }).configuration;
      cfg = if isDarwin then configuration.config.home-manager.users.test else configuration.config;
      extra = configuration.pkgs.mpv;
      plan = cfg.software.plan;
    in
    assert lib.all (a: a.assertion) cfg.assertions;
    assert cfg.software.resolved.mpv.runtimePackage == null;
    assert plan.installations.nix.modulePackages == [ ];
    assert (builtins.head plan.externalReport).status == "external";
    assert (builtins.head plan.externalReport).owners == [ ];
    assert !(builtins.elem (toString configuration.pkgs.hello) (map toString cfg.home.packages));
    if manager == "nix" then
      lib.count (p: toString p == toString extra) cfg.home.packages == 1
      && builtins.elem "${extra}/bin" cfg.home.sessionPath
    else if isDarwin then
      builtins.elem "mpv" plan.installations.homebrew.brews
      && builtins.elem "${cfg.software.nativePrefix}/opt/mpv/bin" cfg.home.sessionPath
    else
      builtins.elem "mpv" plan.installations.pacman.packages;
  shellHost =
    bypass:
    (mkHost "ShellPackageTest" {
      platform = "nixos";
      features = allOff // {
        shell = true;
      };
      hardwareConfig = {
        boot.initrd.enable = false;
        boot.kernel.enable = false;
        boot.loader.grub.enable = false;
      };
      systemConfig = { lib, pkgs, ... }: {
        system.stateVersion = "26.11";
        programs.zsh.package = lib.mkIf bypass pkgs.zsh;
      };
      homeConfig = { pkgs, ... }: {
        home.stateVersion = "26.05";
        software.packageOverrides.zsh = pkgs.zsh.overrideAttrs (_: {
          pname = "custom-zsh";
        });
      };
    }).configuration.config;
  shell = shellHost false;
  shellBypass = shellHost true;
  selectedZsh = shell.home-manager.users.test.software.resolved.zsh.package;
  customLlvm = changedLlvm.software.resolved.llvm.package;
  customOutputs = changedLlvm.software.resolved.llvm.packages;
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
in
assert lib.all (a: a.assertion) (
  sameLlvm.assertions ++ changedLlvm.assertions ++ disabledMpv.assertions
);
assert
  map toString sameLlvm.software.resolved.llvm.packages == [
    (toString sameLlvm.software.resolved.llvm.package)
    (toString sameLlvm.software.resolved.llvm.package.dev)
  ];
assert
  map toString customOutputs == [
    (toString customLlvm)
    (toString customLlvm.dev)
  ];
assert lib.all (p: p.meta.priority == customLlvm.meta.priority) customOutputs;
assert
  lib.count (
    p: toString p == toString sameLlvm.software.resolved.llvm.package.dev
  ) sameLlvm.home.packages == 1;
assert builtins.elem "${customLlvm.dev}/bin" changedLlvm.home.sessionPath;
assert builtins.head changedLlvm.home.sessionPath == "${customLlvm}/bin";
assert !(succeeds (map toString missingOutput.home.packages));
assert disabledMpv.software.resolved.mpv.runtimePackage == null;
assert disabledMpv.software.plan.installations.nix.modulePackages == [ ];
assert !(lib.any (p: lib.hasPrefix "mpv" (lib.getName p)) disabledMpv.home.packages);
assert
  !(builtins.elem "${disabledMpv.software.resolved.mpv.package}/bin" disabledMpv.home.sessionPath);
assert !(succeeds (disabledMpv.software.resolved.mpv.command "mpv"));
assert lib.all disabledExtra [
  "nix"
  "homebrew"
  "pacman"
];
assert lib.all (a: a.assertion) (shell.assertions ++ shell.home-manager.users.test.assertions);
assert toString shell.programs.zsh.package == toString selectedZsh;
assert toString shell.users.users.test.shell == toString selectedZsh;
assert lib.hasInfix (builtins.unsafeDiscardStringContext "HELPDIR=\"${selectedZsh}/")
  shell.environment.etc.zshenv.text;
assert lib.any (
  a: !a.assertion && lib.hasInfix "software.packageOverrides.zsh" a.message
) shellBypass.assertions;
[
  "same-package-override-preserves-outputs"
  "changed-package-override-rebinds-outputs-and-priority"
  "missing-required-output-is-rejected"
  "inactive-wrapper-binding"
  "inactive-wrapper-preserves-explicit-extras-across-providers"
  "nixos-zsh-package-ownership"
]
