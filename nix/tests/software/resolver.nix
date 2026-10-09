{ inputs }:
let
  inherit (inputs.nixpkgs) lib;
  catalog = import ../../lib/software/catalog.nix {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  };
  resolve = import ../../lib/software/resolve.nix {
    inherit lib;
    platformProviders = (import ../../lib/platforms).packageProviders;
  };
  fixture = {
    editor = {
      nix = {
        package = "nix-editor";
        capabilities = [ "store-package" ];
      };
      homebrew = {
        type = "brew";
        name = "editor";
      };
      pacman = {
        type = "package";
        name = "editor";
      };
    };
    font = {
      pacman = {
        type = "aur";
        name = "editor-font";
      };
      nix = {
        package = "nix-font";
        capabilities = [ "store-package" ];
      };
      homebrew = {
        type = "cask";
        name = "font-editor";
      };
    };
    tool.nix = {
      package = "nix-tool";
      capabilities = [ "store-package" ];
    };
    alias = {
      homebrew = {
        type = "brew";
        name = "editor";
      };
    };
    unavailable = {
      homebrew = {
        name = "unavailable";
        type = "brew";
        available = false;
      };
      nix = {
        package = "nix-fallback";
        capabilities = [ "store-package" ];
      };
    };
  };
  plan =
    args:
    resolve (
      {
        catalog = fixture;
        requirements = {
          editor = { };
          font = { };
        };
        packageManager = "homebrew";
        platform = "darwin";
      }
      // args
    );
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  native = plan {
    requirements = {
      editor = { };
      font = { };
      alias = { };
    };
  };
  nix = plan {
    packageManager = "nix";
    platform = "nixos";
  };
  fallback = plan {
    requirements = {
      editor.capabilities = [ "store-package" ];
      font = { };
      tool = { };
      unavailable = { };
    };
  };
  scopes = plan {
    packageManager = "nix";
    requirements = lib.genAttrs [ "editor" "font" ] (_: {
      scopes = [
        "system"
        "home"
      ];
    });
  };
  removed = plan { requirements = { }; };
  remaining = plan { requirements.font = { }; };
  nativeExternal = plan {
    packageManager = {
      type = "homebrew";
      extraPkg.homebrew = {
        brews = [
          "editor"
          "extra"
        ];
        casks = [ "font-editor" ];
      };
    };
  };
  pacman = plan {
    platform = "arch";
    packageManager = {
      type = "pacman";
      extraPkg.pacman = {
        packages = [ "editor" ];
        aur = [
          "editor-font"
          "extra-aur"
        ];
      };
    };
  };
  pacmanFallback = plan {
    platform = "arch";
    packageManager = "pacman";
    requirements = {
      editor.capabilities = [ "store-package" ];
      font = { };
      tool = { };
    };
  };
  nixExternal = resolve {
    inherit catalog;
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    platform = "darwin";
    requirements.vim = { };
    packageManager = {
      type = "nix";
      extraPkg.nix.packages = [
        "vim"
        "vim"
      ];
    };
  };
in
assert
  removed.binPaths == [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
assert builtins.elem "/opt/homebrew/bin" remaining.binPaths;
assert
  (plan {
    nativePrefix = "/usr/local";
    requirements = { };
  }).binPaths == [
    "/usr/local/bin"
    "/usr/local/sbin"
  ];
assert nix.managerBinPaths == [ ];
assert pacman.managerBinPaths == [ ];
assert
  pacman.installations.pacman.packages == [
    "editor"
    "base-devel"
    "git"
  ];
assert
  pacman.installations.pacman.aur == [
    "editor-font"
    "extra-aur"
  ];
assert pacman.resolved.font.nativeType == "aur";
assert pacmanFallback.resolved.editor.provider == "nix";
assert pacmanFallback.resolved.tool.provider == "nix";
assert builtins.length nixExternal.installations.nix.homePackages == 1;
assert native.installations.nix.homePackages == [ ];
assert builtins.length nix.installations.nix.homePackages == 2;
assert fallback.resolved.editor.provider == "nix";
assert fallback.resolved.tool.provider == "nix";
assert fallback.resolved.unavailable.provider == "nix";
assert fallback.resolved.font.provider == "homebrew";
assert
  builtins.length scopes.installations.nix.systemPackages == 2
  && builtins.length scopes.installations.nix.homePackages == 2;
assert
  !(succeeds (plan {
    packageManager = "pacman";
  }));
assert
  !(succeeds (plan {
    packageManager = "typo";
  }));
assert
  !(succeeds (plan {
    platform = "nixos";
  }));
assert
  !(succeeds (plan {
    requirements.typo = { };
  }));
assert
  !(succeeds (plan {
    requirements.editor.capabilities = [ "missing-capability" ];
  }));
assert
  nativeExternal.installations.homebrew.brews == [
    "editor"
    "extra"
  ];
assert nativeExternal.installations.homebrew.casks == [ "font-editor" ];
assert lib.all (args: !(succeeds (plan args))) [
  { packageManager = "apt"; }
  {
    packageManager = {
      type = "homebrew";
      extraPkg.homebrew.aur = [ "x" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      extraPkg.homebrew.brews = [ "--bad" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      extraPkg.homebrew.brews = [ "x; touch BAD" ];
    };
  }
  {
    packageManager = {
      type = "homebrew";
      extraPkg.homebrew.brews = "wrong";
    };
  }
  {
    packageManager = {
      type = "homebrew";
      extra = [ ];
    };
  }
  {
    platform = "arch";
    packageManager = {
      type = "pacman";
      extraPkg.pacman.aur = [ "editor" ];
    };
  }
  {
    platform = "arch";
    packageManager = {
      type = "pacman";
      extraPkg.pacman.aur = [ "git" ];
    };
  }
];
assert native.installations.homebrew.brews == [ "editor" ];
assert native.installations.homebrew.casks == [ "font-editor" ];
assert nix.installations.homebrew.brews == [ ] && nix.installations.homebrew.casks == [ ];
assert
  removed.resolved == { }
  && removed.installations.homebrew.brews == [ ]
  && removed.installations.homebrew.casks == [ ];
assert remaining.installations.homebrew.casks == [ "font-editor" ];
assert
  !(succeeds (plan {
    catalog = fixture // {
      font = fixture.font // {
        unknownMetadata = [ "editor" ];
      };
    };
  }));
assert
  !(succeeds (plan {
    catalog = fixture // {
      editor = fixture.editor // {
        homebew = { };
      };
    };
  }));
assert
  !(succeeds (plan {
    catalog = fixture // {
      editor = fixture.editor // {
        homebrew = {
          name = "editor";
          type = "typo";
        };
      };
    };
  }));
true
