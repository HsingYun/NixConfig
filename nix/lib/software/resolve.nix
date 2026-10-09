{ lib, platformProviders }:
{
  catalog,
  requirements,
  packageManager,
  platform,
  pkgs ? null,
  packageOverrides ? { },
  packageDefaults ? { },
  providerOverrides ? { },
  nativePrefix ? "/opt/homebrew",
}:
let
  manager = import ./manager.nix { inherit lib; } packageManager;
  providers = import ./providers.nix { inherit lib nativePrefix pkgs; };
  supportedProviders =
    platformProviders.${platform} or (throw "Software: unknown platform '${platform}'.");
  supported = provider: builtins.elem provider supportedProviders;
  preferred = manager.type;
  backend = providers.${preferred};
  externalErrors =
    if !builtins.isAttrs manager.extraPkg then
      [ "expected provider groups" ]
    else
      lib.concatMap (
        provider:
        if !(providers ? ${provider}) then
          [ "unknown provider '${provider}'" ]
        else if !(supported provider) then
          [ "provider '${provider}' is unavailable on '${platform}'" ]
        else if !builtins.isAttrs manager.extraPkg.${provider} then
          [ "${provider}: expected package groups" ]
        else
          lib.concatMap (
            group:
            if !(providers.${provider}.externalGroups ? ${group}) then
              [ "${provider}: unknown group '${group}'" ]
            else
              lib.optional (
                !(
                  builtins.isList manager.extraPkg.${provider}.${group}
                  && lib.all providers.${provider}.validName manager.extraPkg.${provider}.${group}
                )
              ) "${provider}.${group}: expected valid package names"
          ) (builtins.attrNames manager.extraPkg.${provider})
      ) (builtins.attrNames manager.extraPkg);
  externalRequests = lib.concatLists (
    lib.mapAttrsToList (
      provider: groups:
      let
        externalBackend = providers.${provider};
      in
      lib.concatLists (
        lib.mapAttrsToList (
          group: names:
          map (
            name:
            let
              source = externalBackend.externalRecipe externalBackend.externalGroups.${group} name;
            in
            assert lib.assertMsg (source.available or true
            ) "Software: external package '${name}' is unavailable.";
            {
              inherit
                name
                source
                group
                provider
                ;
              capabilities = [ ];
              providedCapabilities = source.capabilities or [ ];
              scopes = [ "home" ];
            }
            // externalBackend.resolve source
          ) (lib.unique names)
        ) groups
      )
    ) manager.extraPkg
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
          if !(providers ? ${provider}) then
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
    assert lib.assertMsg (supported preferred)
      "Software: package manager '${preferred}' does not support platform '${platform}'.";
    true;
  names = builtins.attrNames requirements;
  select =
    name:
    assert lib.assertMsg (catalog ? ${name}) "Software: unknown software '${name}'.";
    let
      entry = catalog.${name};
      request = requirements.${name} or { };
      capabilities = lib.unique (request.capabilities or [ ]);
      overridden = packageOverrides ? ${name};
      candidates =
        if overridden then
          [ "nix" ]
        else if providerOverrides ? ${name} then
          [ providerOverrides.${name} ]
        else
          lib.unique ([ preferred ] ++ providers.${preferred}.fallback);
      recipes =
        entry
        // lib.optionalAttrs (overridden || packageDefaults ? ${name}) {
          nix =
            (entry.nix or { })
            // (import ./recipe-constructors.nix).nix (
              if overridden then packageOverrides.${name} else packageDefaults.${name}
            )
            // {
              capabilities = lib.unique ([ "store-package" ] ++ (entry.nix.capabilities or [ ]));
            };
        };
      usable =
        provider:
        providers ? ${provider}
        && supported provider
        && recipes ? ${provider}
        && (recipes.${provider}.available or true)
        && lib.all (cap: builtins.elem cap (recipes.${provider}.capabilities or [ ])) capabilities;
      available = lib.filter usable candidates;
      provider =
        if available == [ ] then
          throw (
            "Software: '${name}' has no usable provider in ${lib.concatStringsSep ", " candidates}; required capabilities: ${lib.concatStringsSep ", " capabilities}."
            + lib.optionalString (
              (request.requiredBy or [ ]) != [ ]
            ) " Requested by: ${lib.concatStringsSep ", " request.requiredBy}."
          )
        else
          builtins.head available;
      source = recipes.${provider};
    in
    {
      inherit provider capabilities;
      mainProgram = source.mainProgram or (source.package.meta.mainProgram or null);
      providedCapabilities = source.capabilities or [ ];
      scopes = lib.unique (request.scopes or [ "home" ]);
      reason =
        if overridden then
          "explicit package override"
        else if providerOverrides ? ${name} then
          "explicit provider override"
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
        (
          entry ? ${extra.provider}
          && providers.${extra.provider}.samePackage extra.source entry.${extra.provider}
        )
        || (
          selected.provider == extra.provider
          && providers.${extra.provider}.samePackage extra.source (
            if extra.provider == "nix" then
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
    name: resolved.${name}.provider != "nix" || resolved.${name}.scopes != [ ]
  ) names;
  planInstallations =
    {
      installedOwners,
      runtimePackages ? { },
      runtimeScopes ? { },
    }:
    let
      reconciledExtras = map (
        extra:
        extra
        // {
          owners = lib.intersectLists installedOwners extra.owners;
        }
      ) matchedExtras;
      # Express the extras policy once through upstream package metadata.
      # buildEnv resolves the resulting priorities and output collisions.
      selectedPackages = lib.concatLists (
        lib.mapAttrsToList (
          name: entry:
          if entry.provider != "nix" then
            [ ]
          else if (runtimePackages.${name} or null) != null then
            [ runtimePackages.${name} ]
          else
            entry.packages
        ) resolved
      );
      externalPriority =
        1
        + lib.foldl' lib.max lib.meta.defaultPriority (
          map (package: package.meta.priority or lib.meta.defaultPriority) selectedPackages
        );
      externalEntries = map (
        extra:
        extra
        // lib.optionalAttrs (extra.provider == "nix") {
          # An extra compiler/tool must not replace feature-owned commands.
          packages = map (lib.setPrio externalPriority) extra.packages;
        }
      ) (lib.filter (extra: extra.owners == [ ]) reconciledExtras);
      values =
        lib.mapAttrsToList (
          name: entry:
          let
            runtime = runtimePackages.${name} or null;
          in
          entry
          // lib.optionalAttrs (entry.provider == "nix" && runtime != null) {
            # Reuse the upstream wrapper in any additional requested scope.
            # Its producing module already installs it in runtimeScopes.
            packages = [ runtime ];
            scopes = lib.subtractLists (runtimeScopes.${name} or [ ]) entry.scopes;
          }
        ) resolved
        ++ externalEntries;
      # Explicit providers need their command directories even when they are
      # not the host default (e.g. Homebrew cask links with a Nix default).
      activeProviders = lib.unique ([ preferred ] ++ map (entry: entry.provider) values);
      managerBinPaths = lib.unique (
        lib.concatMap (provider: providers.${provider}.managerBinPaths or [ ]) activeProviders
      );
    in
    {
      externalReport = map (extra: {
        inherit (extra)
          name
          group
          owners
          provider
          ;
        status = if extra.owners == [ ] then "external" else "provided-by-feature";
      }) reconciledExtras;
      installations = lib.mapAttrs (
        provider: backend: backend.plan (lib.filter (entry: entry.provider == provider) values)
      ) providers;
      inherit managerBinPaths;
      binPaths = lib.unique (lib.concatMap (entry: entry.binPaths) values ++ managerBinPaths);
    };

in
assert checkManager;
assert lib.assertMsg (lib.all (name: catalog ? ${name} && catalog.${name} ? nix) (
  builtins.attrNames packageDefaults
)) "Software: packageDefaults must refer to existing Nix recipes.";
assert lib.assertMsg (lib.all (name: catalog ? ${name}) (
  builtins.attrNames providerOverrides
)) "Software: providerOverrides contains an unknown software identifier.";
assert lib.assertMsg (lib.all (provider: providers ? ${provider} && supported provider) (
  builtins.attrValues providerOverrides
)) "Software: providerOverrides selects an unsupported provider.";
assert lib.assertMsg (lib.all
  (name: !(providerOverrides ? ${name}) || providerOverrides.${name} == "nix")
  (builtins.attrNames packageOverrides)
) "Software: a package override conflicts with a non-Nix provider override.";
assert lib.assertMsg (lib.all (name: catalog ? ${name}) (
  builtins.attrNames packageOverrides
)) "Software: packageOverrides contains an unknown software identifier.";
assert lib.assertMsg (
  externalErrors == [ ]
) "Software ${preferred} extraPkg: ${lib.concatStringsSep "; " externalErrors}";
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
// planInstallations { inherit installedOwners; }
