{ lib }:
{
  catalog,
  requirements,
  packageManager,
  platform,
  pkgs ? null,
  packageOverrides ? { },
  nativePrefix ? "/opt/homebrew",
}:
let
  nixPackages = import ./nix-packages.nix { inherit lib; };
  manager = import ./manager.nix { inherit lib; } packageManager;
  providers = import ./providers.nix { inherit lib nativePrefix pkgs; };
  preferred = manager.type;
  backend = providers.${preferred};
  externalErrors =
    if !builtins.isAttrs manager.externalPkg then
      [ "expected an attribute set" ]
    else
      lib.concatMap (
        group:
        if !(backend.externalGroups ? ${group}) then
          [ "unknown group '${group}'" ]
        else if
          !(
            builtins.isList manager.externalPkg.${group}
            && lib.all backend.validName manager.externalPkg.${group}
          )
        then
          [ "${group}: expected a list of package names" ]
        else
          [ ]
      ) (builtins.attrNames manager.externalPkg);
  externalRequests = lib.concatLists (
    lib.mapAttrsToList (
      group: names:
      map (
        name:
        let
          source = backend.externalRecipe backend.externalGroups.${group} name;
        in
        assert lib.assertMsg (source.available or true
        ) "Software: external package '${name}' is unavailable.";
        {
          inherit name source;
          group = group;
          provider = preferred;
          capabilities = [ ];
          providedCapabilities = source.capabilities or [ ];
          scopes = [ "home" ];
          installNix = true;
        }
        // backend.resolve source
      ) (lib.unique names)
    ) manager.externalPkg
  );
  # Validate recipe structure without forcing unselected Nix derivations.
  recipeErrors = lib.concatLists (
    lib.mapAttrsToList (
      name: entry:
      if !builtins.isAttrs entry then
        [ "${name}: expected a software definition" ]
      else
        lib.concatMap (
          provider:
          if provider == "dependencies" then
            lib.optional (
              !(builtins.isList entry.dependencies && lib.all builtins.isString entry.dependencies)
            ) "${name}: dependencies must be software identifiers"
          else if !(providers ? ${provider}) then
            [ "${name}: unknown provider '${provider}'" ]
          else
            let
              source = entry.${provider};
              backend = providers.${provider};
            in
            if !builtins.isAttrs source then
              [ "${name}.${provider}: expected a recipe" ]
            else
              lib.optional (!(backend.validate source)) "${name}.${provider}: invalid recipe"
              ++ map (field: "${name}.${provider}: unknown field '${field}'") (
                lib.subtractLists backend.fields (builtins.attrNames source)
              )
        ) (builtins.attrNames entry)
    ) catalog
  );
  checkManager =
    assert lib.assertMsg (providers ? ${preferred})
      "Software: package manager '${preferred}' has no implemented backend (supported: ${lib.concatStringsSep ", " (builtins.attrNames providers)}).";
    assert lib.assertMsg (builtins.elem platform
      providers.${preferred}.platforms
    ) "Software: package manager '${preferred}' does not support platform '${platform}'.";
    true;
  visit =
    trail: name:
    assert lib.assertMsg (catalog ? ${name}) "Software: unknown software '${name}'.";
    assert lib.assertMsg (!(builtins.elem name trail))
      "Software: dependency cycle ${lib.concatStringsSep " -> " (trail ++ [ name ])}.";
    [ name ] ++ lib.concatMap (visit (trail ++ [ name ])) (catalog.${name}.dependencies or [ ]);
  closures = lib.mapAttrs (name: _: visit [ ] name) requirements;
  names = lib.unique (lib.concatLists (builtins.attrValues closures));
  # Dependencies inherit installation scopes, but have their own capabilities.
  scopesFor =
    name:
    lib.unique (
      lib.concatMap (
        root:
        lib.optionals (builtins.elem name closures.${root}) (requirements.${root}.scopes or [ "home" ])
      ) (builtins.attrNames requirements)
    );
  select =
    name:
    let
      entry = catalog.${name};
      request = requirements.${name} or { };
      capabilities = lib.unique (request.capabilities or [ ]);
      overridden = packageOverrides ? ${name};
      candidates =
        if overridden then [ "nix" ] else lib.unique ([ preferred ] ++ providers.${preferred}.fallback);
      recipes =
        entry
        // lib.optionalAttrs overridden {
          nix =
            (entry.nix or { })
            // (import ./recipes.nix { inherit pkgs; }).nix packageOverrides.${name}
            // {
              capabilities = lib.unique ([ "store-package" ] ++ (entry.nix.capabilities or [ ]));
            };
        };
      usable =
        provider:
        builtins.elem platform providers.${provider}.platforms
        && recipes ? ${provider}
        && (recipes.${provider}.available or true)
        && lib.all (cap: builtins.elem cap (recipes.${provider}.capabilities or [ ])) capabilities;
      available = lib.filter usable candidates;
      provider =
        if available == [ ] then
          throw "Software: '${name}' has no usable provider in ${lib.concatStringsSep ", " candidates}; required capabilities: ${lib.concatStringsSep ", " capabilities}."
        else
          builtins.head available;
      source = recipes.${provider};
    in
    {
      inherit provider capabilities;
      providedCapabilities = source.capabilities or [ ];
      scopes = scopesFor name;
      installNix = request.installNix or true;
      reason =
        if overridden then
          "explicit package override"
        else if provider == preferred then
          "preferred"
        else if !(entry ? ${preferred}) then
          "${preferred}: no implementation"
        else if !(entry.${preferred}.available or true) then
          "${preferred}: unavailable on this platform"
        else
          "${preferred}: missing required capabilities (${lib.concatStringsSep ", " capabilities})";
    }
    // providers.${provider}.resolve source;
  resolved = lib.genAttrs names select;
  # Match identities first; final installation ownership is checked separately.
  matchedExtras = map (
    extra:
    let
      owners = lib.filter (
        name:
        let
          entry = catalog.${name};
          selected = resolved.${name};
        in
        (entry ? ${preferred} && backend.samePackage extra.source entry.${preferred})
        || (
          selected.provider == preferred
          && backend.samePackage extra.source (
            if preferred == "nix" then
              { package = selected.package; }
            else
              {
                name = selected.nativeName;
                type = selected.nativeType;
              }
          )
        )
      ) names;
    in
    extra // { inherit owners; }
  ) externalRequests;
  # Upstream wrappers are only owners once materialization confirms that the
  # module actually installs them. Unbound resources cannot satisfy extras.
  installedOwners = lib.filter (
    name: resolved.${name}.provider != "nix" || resolved.${name}.installNix
  ) names;
  planInstallations =
    installedOwners:
    let
      reconciledExtras = map (
        extra:
        extra
        // {
          owners = lib.intersectLists installedOwners extra.owners;
        }
      ) matchedExtras;
      # Compiler wrappers already use lowPrio's priority (10). Put extras below
      # every selected package instead of assigning that same priority again.
      externalPriority =
        1
        + lib.foldl' lib.max lib.meta.defaultPriority (
          lib.concatMap (entry: map nixPackages.priority entry.packages) (
            lib.filter (entry: entry.provider == "nix") (builtins.attrValues resolved)
          )
        );
      externalEntries = map (
        extra:
        extra
        // lib.optionalAttrs (preferred == "nix") {
          # An extra compiler/tool must not replace feature-owned commands.
          packages = map (lib.setPrio externalPriority) extra.packages;
        }
      ) (lib.filter (extra: extra.owners == [ ]) reconciledExtras);
      values = builtins.attrValues resolved ++ externalEntries;
    in
    {
      externalNixPackages = lib.concatMap (entry: entry.packages) (
        lib.filter (entry: entry.provider == "nix") externalEntries
      );
      externalReport = map (extra: {
        inherit (extra) name group owners;
        status = if extra.owners == [ ] then "external" else "provided-by-feature";
      }) reconciledExtras;
      installations = lib.mapAttrs (
        provider: backend: backend.plan (lib.filter (entry: entry.provider == provider) values)
      ) providers;
      selectedBinPaths = lib.unique (
        lib.concatMap (entry: entry.binPaths) (builtins.attrValues resolved)
      );
      externalBinPaths = lib.unique (lib.concatMap (entry: entry.binPaths) externalEntries);
      binPaths = lib.unique (lib.concatMap (entry: entry.binPaths) values);
    };

in
assert checkManager;
assert lib.assertMsg (lib.all (name: catalog ? ${name}) (
  builtins.attrNames packageOverrides
)) "Software: packageOverrides contains an unknown software identifier.";
assert lib.assertMsg (
  externalErrors == [ ]
) "Software ${preferred} externalPkg: ${lib.concatStringsSep "; " externalErrors}";
assert lib.assertMsg (
  recipeErrors == [ ]
) "Software catalog: ${lib.concatStringsSep "; " recipeErrors}";
{
  inherit resolved manager planInstallations;
  report = lib.mapAttrs (_: entry: {
    inherit (entry)
      provider
      reason
      scopes
      capabilities
      providedCapabilities
      nativeName
      nativeType
      ;
  }) resolved;
}
// planInstallations installedOwners
