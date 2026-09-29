{ lib, catalog }:
let
  specs = lib.concatLists (
    lib.mapAttrsToList (
      name: entry:
      let
        path = entry.path or [ name ];
      in
      [
        {
          path = path ++ [ "enable" ];
          check = builtins.isBool;
          description = "a boolean";
          default = entry.default or false;
        }
      ]
      ++ lib.mapAttrsToList (key: option: option // { path = path ++ [ key ]; }) (entry.options or { })
    ) catalog.features
  );
  schema = lib.foldl' lib.recursiveUpdate { } (
    map (spec: lib.setAttrByPath spec.path { _leaf = spec; }) specs
  );
  validate =
    path: node: value:
    if node ? _leaf then
      lib.optional (!(node._leaf.check value)) "${path} must be ${node._leaf.description}."
    else if !builtins.isAttrs value then
      [ "${path} must be an attribute set; use .enable for feature switches." ]
    else
      lib.concatMap (
        key:
        if node ? ${key} then
          validate "${path}.${key}" node.${key} value.${key}
        else
          [ "unknown ${path}.${key}." ]
      ) (builtins.attrNames value);
in
{
  inherit specs;
  normalize = source: values: {
    errors = validate source schema values;
    values = lib.listToAttrs (
      lib.concatMap (
        spec:
        let
          value = lib.attrByPath spec.path null values;
        in
        lib.optional (lib.hasAttrByPath spec.path values && spec.check value) {
          name = lib.concatStringsSep "." spec.path;
          inherit value;
        }
      ) specs
    );
  };
}
