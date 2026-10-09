{ inputs, ownershipHost }:
let
  inherit (inputs.nixpkgs) lib;
  make =
    bypass: enabled:
    ownershipHost "nix" { } (
      { pkgs, ... }: {
        imports = [ ../../modules/home/shared/desktop.nix ];
        gtk.enable = enabled;
        software.packageOverrides.tela = pkgs.tela-icon-theme.overrideAttrs { pname = "custom-tela"; };
        gtk.iconTheme.package = lib.mkIf bypass (lib.mkForce pkgs.tela-icon-theme);
      }
    );
  custom = make false true;
  bypass = make true true;
  disabled = make true false;
  lfs =
    manager: enabled:
    ownershipHost manager
      {
        git = true;
        devel = true;
      }
      {
        programs.git.lfs.enable = enabled;
      };
  nativeLfs = lfs "pacman" true;
  nixLfs = lfs "nix" true;
  disabledLfs = lfs "nix" false;
  directLfs = ownershipHost "pacman" { } {
    programs.git = {
      enable = true;
      lfs.enable = true;
    };
  };
  disabledGit = ownershipHost "nix" { devel = true; } {
    programs.git = {
      enable = false;
      lfs.enable = true;
    };
  };
  lfsBypass =
    ownershipHost "pacman"
      {
        git = true;
        devel = true;
      }
      (
        { pkgs, ... }: {
          programs.git.lfs = {
            enable = true;
            package = pkgs.git-lfs;
          };
        }
      );
  idleGpg = ownershipHost "pacman" { commonTools = true; } { };
  droppedRequest = ownershipHost "nix" { devel = true; } (
    { lib, ... }: {
      home.packages = lib.mkForce [ ];
    }
  );
  falseClaim = ownershipHost "nix" { git = true; } {
    imports = [
      (import ../../modules/software/consumer.nix {
        scope = "home";
        id = "test-false-system-claim";
        software = "git";
        enableOptions = [
          [
            "programs"
            "git"
            "enable"
          ]
        ];
        packageOption = [
          "programs"
          "git"
          "package"
        ];
        installedScopes = [ "system" ];
      })
    ];
  };
  valid = cfg: lib.all (a: a.assertion) cfg.assertions;
  # The inventory itself must name real requested identities and usable paths.
  registry =
    (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ../../modules/home/software
        {
          home.username = "test";
          home.homeDirectory = "/home/test";
          home.stateVersion = "26.05";
          software.platform = "arch";
        }
      ];
    }).config.software.consumers;
  # Exercise each installer through the public upstream options, without its
  # feature preset supplying demand. Resource bindings do not select software.
  directConsumers = lib.mapAttrs (
    name: consumer:
    ownershipHost "pacman" { } {
      config = lib.mkMerge (map (path: lib.setAttrByPath path true) consumer.enableOptions);
    }
  ) (lib.filterAttrs (_: consumer: consumer.requestWhenEnabled) registry);
  themeOnly = ownershipHost "pacman" { } { gtk.enable = true; };
  catalog = import ../../lib/software/catalog.nix {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  };
in
assert lib.all (name: catalog ? ${registry.${name}.software}) (builtins.attrNames registry);
assert valid custom && valid disabled;
assert lib.all (
  name:
  let
    cfg = directConsumers.${name};
    software = registry.${name}.software;
  in
  valid cfg
  && cfg.software.resolved ? ${software}
  &&
    lib.getAttrFromPath registry.${name}.packageOption cfg == cfg.software.resolved.${software}.package
) (builtins.attrNames directConsumers);
assert !(themeOnly.software.resolved ? tela);
assert valid nativeLfs && valid nixLfs && valid directLfs && valid disabledLfs;
assert nativeLfs.programs.git.lfs.package == null;
assert nativeLfs.gtk.iconTheme == null;
assert valid idleGpg;
assert idleGpg.software.resolved.gnupg.provider == "pacman";
assert !idleGpg.programs.gpg.enable && idleGpg.programs.gpg.package != null;
assert directLfs.software.resolved.git-lfs.provider == "pacman";
assert directLfs.software.resolved.git.provider == "pacman";
assert directLfs.programs.git.package == null;
assert !(lib.any (p: lib.getName p == "git") directLfs.home.packages);
assert directConsumers.home-vim.software.resolved.vim.provider == "pacman";
assert nativeLfs.programs.git.iniContent.filter.lfs.clean == "git-lfs clean -- %f";
assert !(lib.any (p: lib.getName p == "git-lfs") nativeLfs.home.packages);
assert builtins.elem "git-lfs" nativeLfs.software.plan.installations.pacman.packages;
assert builtins.elem (toString nixLfs.programs.git.lfs.package) (map toString nixLfs.home.packages);
assert lib.count (p: lib.getName p == "git-lfs") nixLfs.home.packages == 1;
assert !(disabledLfs.software.runtimeArtifacts ? home-git-lfs);
assert valid disabledGit;
assert !(disabledGit.software.runtimeArtifacts ? home-git-lfs);
assert lib.any (p: lib.getName p == "git-lfs") disabledGit.home.packages;
assert lib.any (p: lib.getName p == "git-lfs") disabledLfs.home.packages;
assert !(builtins.tryEval lfsBypass.home.username).success;
assert !(builtins.tryEval falseClaim.home.username).success;
assert !(builtins.tryEval droppedRequest.home.username).success;
assert toString custom.gtk.iconTheme.package == toString custom.software.resolved.tela.package;
assert builtins.elem (toString custom.gtk.iconTheme.package) (map toString custom.home.packages);
assert !(builtins.tryEval bypass.home.username).success;
{
  managedThemeUsesSelectedPackage = true;
  optionalUpstreamConsumerFollowsSelectedProvider = true;
  directConsumersParticipateWithoutFeatures = builtins.attrNames directConsumers;
  resourceBindingsDoNotSelectAnApplication = true;
  disabledConsumerPreservesIndependentProfileRequest = true;
  packageOptionBypassRejected = true;
  inactiveConsumerDoesNotConstrainPackage = true;
}
