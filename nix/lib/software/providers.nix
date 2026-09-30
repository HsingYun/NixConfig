{
  lib,
  nativePrefix,
  pkgs ? null,
}:
let
  # Recipes may explicitly request extra outputs (e.g. llvm.dev). Default
  # output selection remains buildEnv's responsibility.
  selectOutputs =
    package: outputs:
    if outputs == null then
      [ package ]
    else
      map (
        name:
        assert lib.assertMsg (builtins.elem name (
          package.outputs or [ "out" ]
        )) "Software: package '${lib.getName package}' does not provide required output '${name}'.";
        lib.setPrio (package.meta.priority or lib.meta.defaultPriority) (lib.getOutput name package)
      ) outputs;
  validName =
    name: builtins.isString name && builtins.match "[A-Za-z0-9][A-Za-z0-9+._/@:-]*" name != null;
  namesFor =
    type: entries:
    lib.unique (map (entry: entry.nativeName) (lib.filter (entry: entry.nativeType == type) entries));
  packagesFor =
    scope: entries:
    lib.unique (
      lib.concatMap (
        entry: lib.optionals (entry.installNix && builtins.elem scope entry.scopes) entry.packages
      ) entries
    );
in
{
  nix = {
    samePackage =
      a: b:
      lib.intersectLists (map toString (selectOutputs a.package (a.outputs or null))) (
        map toString (selectOutputs b.package (b.outputs or null))
      ) != [ ];
    externalGroups = {
      packages = "package";
    };
    externalRecipe =
      _: name:
      assert lib.assertMsg (pkgs != null) "Software: Nix extraPkg requires a package set.";
      (import ./recipes.nix { inherit pkgs; }).nix (
        lib.attrByPath (lib.splitString "." name) (throw "Software: unknown Nix package '${name}'.") pkgs
      );
    inherit validName;
    fields = [
      "package"
      "outputs"
      "capabilities"
      "available"
    ];
    validate =
      source:
      source ? package
      && (
        !(source ? outputs)
        || (
          builtins.isList source.outputs
          && source.outputs != [ ]
          && lib.all builtins.isString source.outputs
          && lib.unique source.outputs == source.outputs
        )
      );

    platforms = (import ../hosts/platforms.nix).all;
    fallback = [ ];
    resolve = source: {
      package = source.package;
      packages = selectOutputs source.package (source.outputs or null);
      nativeName = null;
      nativeType = null;
      binPaths = [ ];
      command = executable: lib.getExe' source.package executable;
    };
    plan = entries: {
      homePackages = packagesFor "home" entries;
      enableFontconfig = lib.any (entry: builtins.elem "font" entry.providedCapabilities) entries;
      systemPackages = packagesFor "system" entries;
    };
  };
  homebrew = {
    # Keep the manager and linked cask commands available without shellenv.
    managerBinPaths = [
      "${nativePrefix}/bin"
      "${nativePrefix}/sbin"
    ];
    samePackage = a: b: a.name == b.name && a.type == b.type;
    externalGroups = {
      brews = "brew";
      casks = "cask";
    };
    externalRecipe = type: name: { inherit type name; };
    inherit validName;
    fields = [
      "name"
      "type"
      "capabilities"
      "available"
      "binDirs"
      "commandDir"
    ];
    validate =
      source:
      source ? name
      && validName source.name
      && builtins.elem (source.type or null) [
        "brew"
        "cask"
      ];

    platforms = [ "darwin" ];
    fallback = [ "nix" ];
    resolve =
      source:
      let
        formulaName = lib.last (lib.splitString "/" source.name);
      in
      {
        package = null;
        packages = [ ];
        nativeName = source.name;
        nativeType = source.type;
        binPaths = lib.optionals (source.type == "brew") (
          map (dir: "${nativePrefix}/opt/${formulaName}/${dir}") (source.binDirs or [ "bin" ])
        );
        command =
          executable:
          if source.type == "brew" then
            "${nativePrefix}/opt/${formulaName}/${source.commandDir or "bin"}/${executable}"
          else
            "${nativePrefix}/bin/${executable}";
      };
    plan = entries: {
      brews = namesFor "brew" entries;
      casks = namesFor "cask" entries;
    };
  };
  pacman = {
    samePackage = a: b: a.name == b.name && a.type == b.type;
    fields = [
      "name"
      "type"
      "capabilities"
      "available"
    ];
    externalGroups = {
      packages = "package";
      aur = "aur";
    };
    externalRecipe = type: name: { inherit type name; };
    validName = name: validName name && !(lib.hasInfix "/" name) && !(lib.hasInfix ":" name);
    validate =
      source:
      source ? name
      && validName source.name
      && !(lib.hasInfix "/" source.name)
      && !(lib.hasInfix ":" source.name)
      && builtins.elem (source.type or null) [
        "package"
        "aur"
      ];
    platforms = [ "arch" ];
    fallback = [ "nix" ];
    resolve = source: {
      package = null;
      packages = [ ];
      nativeName = source.name;
      nativeType = source.type;
      binPaths = [ ];
      command = executable: "/usr/bin/${executable}";
    };
    plan =
      entries:
      let
        packages = lib.unique (
          namesFor "package" entries
          ++ lib.optionals (aur != [ ]) [
            "base-devel"
            "git"
          ]
        );
        aur = namesFor "aur" entries;
      in
      assert lib.assertMsg (
        lib.intersectLists packages aur == [ ]
      ) "Software: a pacman package cannot be requested from both repositories and AUR.";
      {
        inherit packages;
        inherit aur;
      };
  };
}
