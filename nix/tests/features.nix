{ lib }:

let
  catalog = import ../lib/features/catalog.nix;
  resolve = import ../lib/features/resolve.nix { inherit lib; };
  names = builtins.attrNames catalog.features;
  platforms = [
    "linux"
    "nixos"
    "nixos-wsl"
    "darwin"
  ];
  # Independent compatibility specification. Update when adding a feature.
  all = platforms;
  support = {
    efiTools = [
      "linux"
      "nixos"
    ];
    chrome = all;
    vscode = all;
    codex = all;
    mapleMono = all;
    coteditor = [ "darwin" ];
    iina = [ "darwin" ];
    edge = [ "darwin" ];
    screenRotate = [ "nixos" ];
    plymouth = [ "nixos" ];
    network = [ "nixos" ];
    devel = all;
    git = all;
    vim = all;
    shell = all;
    gpg = all;
    gpgSshSupport = all;
    nixTools = all;
    mpv = all;
    xdg = [
      "linux"
      "nixos"
      "nixos-wsl"
    ];
    smartcard = [
      "nixos"
      "nixos-wsl"
      "darwin"
    ];
    nixLd = [
      "nixos"
      "nixos-wsl"
    ];
    gnome = [ "nixos" ];
    niri = [ "nixos" ];
    dms = [ "nixos" ];
    ghostty = all;
    chinese = [
      "linux"
      "nixos"
      "nixos-wsl"
    ];
  };
  allOff = lib.genAttrs names (_: false);
  combinationsFor =
    keys:
    lib.cartesianProduct (
      lib.genAttrs keys (_: [
        false
        true
      ])
    );
  # Exhaust only related features. Adding an independent feature adds one case
  # per platform instead of doubling a repository-wide Cartesian product.
  dependencyPairs = lib.concatMap (
    name:
    map (other: [
      name
      other
    ]) (catalog.features.${name}.requires or [ ])
  ) names;
  conflictPairs = lib.concatMap (
    name:
    map (other: [
      name
      other
    ]) (catalog.features.${name}.conflicts or [ ])
  ) names;
  choiceGroups = map (choice: lib.unique (builtins.attrValues choice.providers)) (
    builtins.attrValues catalog.choices
  );
  combinations = lib.unique (
    [ allOff ]
    ++ map (name: allOff // { ${name} = true; }) names
    ++ lib.concatMap (keys: map (row: allOff // row) (combinationsFor keys)) (
      dependencyPairs ++ conflictPairs ++ choiceGroups
    )
  );
  check =
    args:
    resolve (
      {
        name = "test";
        platform = "nixos";
      }
      // args
    );
  valid = args: (check args).errors == [ ];
  expected =
    platform: f:
    lib.all (key: !f.${key} || builtins.elem platform support.${key}) names
    && !(f.gnome && f.niri)
    && !(f.gnome && f.dms);
  counts = lib.genAttrs platforms (
    platform:
    lib.foldl'
      (
        count: overrides:
        let
          result = check { inherit platform overrides; };
          ok = expected platform overrides;
        in
        assert lib.assertMsg ((result.errors == [ ]) == ok)
          "Feature matrix mismatch: ${builtins.toJSON { inherit platform overrides; }}";
        assert !ok || result.enabled == overrides;
        let
          next = {
            accepted = count.accepted + (if ok then 1 else 0);
            rejected = count.rejected + (if ok then 0 else 1);
          };
        in
        # Keep counters strict as the feature matrix grows.
        builtins.deepSeq next next
      )
      {
        accepted = 0;
        rejected = 0;
      }
      combinations
  );
  # Exercise default selection, explicit disabling, and shared/local precedence
  # for every feature, including unsupported shared defaults.
  checkDefaults =
    platform: name:
    let
      supported = builtins.elem platform support.${name};
      baseline = check { inherit platform; };
      disabled = check {
        inherit platform;
        overrides.${name} = false;
      };
      inherited = check {
        inherit platform;
        defaults = allOff // {
          ${name} = true;
        };
      };
      overridden = check {
        inherit platform;
        defaults = allOff // {
          ${name} = true;
        };
        overrides.${name} = false;
      };
    in
    assert baseline.enabled.${name} == (supported && (catalog.features.${name}.default or false));
    assert disabled.errors == [ ] && !disabled.enabled.${name};
    assert inherited.errors == [ ] && inherited.enabled.${name} == supported;
    assert overridden.errors == [ ] && overridden.enabled == allOff;
    true;
  desktopCases = lib.cartesianProduct {
    gnome = [
      false
      true
    ];
    niri = [
      false
      true
    ];
    dms = [
      false
      true
    ];
    desktop = [
      null
      "gnome"
      "niri"
    ];
    loginManager = [
      null
      "none"
      "gdm"
      "dms"
    ];
  };
  checkDesktop =
    c:
    let
      desktopCount = (if c.gnome then 1 else 0) + (if c.niri then 1 else 0);
      managerCount = (if c.gnome then 1 else 0) + (if c.dms then 1 else 0);
      expectedValid =
        (
          if c.desktop == null then
            desktopCount <= 1
          else if c.desktop == "gnome" then
            c.gnome
          else
            c.niri
        )
        && (
          if c.loginManager == null then
            managerCount <= 1
          else
            c.loginManager == "none"
            || (c.loginManager == "gdm" && c.gnome)
            || (c.loginManager == "dms" && c.dms)
        );
    in
    valid {
      overrides = { inherit (c) gnome niri dms; };
      preferences = { inherit (c) desktop loginManager; };
    } == expectedValid;
  extra = [
    ((check { overrides.gpg = false; }).enabled.gpgSshSupport)
    (valid { defaults.gpg = false; })
    (
      (valid {
        overrides = {
          gpg = false;
          gpgSshSupport = true;
        };
      })
    )
    (
      (valid {
        defaults.gpgSshSupport = true;
        overrides.gpg = false;
      })
    )
    (valid {
      defaults.gpgSshSupport = true;
      overrides = {
        gpg = false;
        gpgSshSupport = false;
      };
    })
    (valid {
      platform = "linux";
      defaults.gnome = true;
    })
    (
      !(valid {
        platform = "linux";
        overrides.gnome = true;
      })
    )
    (!(valid { overrides.typo = true; }))
    (!(valid { overrides.git = "true"; }))
    (!(valid { defaults = [ ]; }))
    (!(valid { preferences.typo = "gnome"; }))
    (!(valid { preferences.desktop = true; }))
    (!(valid { preferences = [ ]; }))
    (valid {
      overrides = {
        dms = true;
        niri = false;
      };
    })
    (lib.any (lib.hasInfix "preferences.desktop explicitly")
      (check {
        overrides = {
          gnome = true;
          niri = true;
        };
      }).errors
    )
  ];
  conflictCatalog = catalog // {
    features = catalog.features // {
      git = catalog.features.git // {
        conflicts = [ "mpv" ];
      };
    };
  };
  conflict =
    overrides:
    import ../lib/features/resolve.nix
      {
        inherit lib;
        catalog = conflictCatalog;
      }
      {
        name = "conflict";
        platform = "nixos";
        overrides = allOff // overrides;
      };
  cyclicCatalog = catalog // {
    features = catalog.features // {
      gpg = catalog.features.gpg // {
        requires = [ "gpgSshSupport" ];
      };
    };
  };
  cycle = builtins.tryEval (
    builtins.deepSeq (import ../lib/features/resolve.nix
      {
        inherit lib;
        catalog = cyclicCatalog;
      }
      {
        name = "cycle";
        platform = "nixos";
      }
    ) true
  );
in
assert names == builtins.attrNames support;
assert lib.all checkDesktop desktopCases;
assert lib.all (x: x) extra;
assert lib.all (platform: lib.all (checkDefaults platform) names) platforms;
assert lib.all (f: ((conflict f).errors == [ ]) == !(f.git && f.mpv)) (combinationsFor [
  "git"
  "mpv"
]);
assert !cycle.success;
{
  inherit counts;
  catalogValidation = import ./catalog.nix { inherit lib; };
  targetedCombinations = builtins.length combinations * builtins.length platforms;
  defaultCases = builtins.length names * builtins.length platforms;
  desktopChoices = builtins.length desktopCases;
  edgeCases = builtins.length extra + 2;
}
