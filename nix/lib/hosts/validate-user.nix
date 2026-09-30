{ lib, name }:

source: user:

let
  checkFields =
    path: allowed: value:
    assert lib.assertMsg (builtins.isAttrs value) "Host ${name}: ${path} must be an attribute set.";
    let
      unknown = lib.subtractLists allowed (builtins.attrNames value);
    in
    assert lib.assertMsg (unknown == [ ])
      "Host ${name}: unknown ${path} fields: ${lib.concatStringsSep ", " unknown}. Allowed fields: ${lib.concatStringsSep ", " allowed}.";
    value;
  nonEmptyText =
    value:
    builtins.isString value
    && builtins.match ".*[^[:space:]].*" value != null
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\r" value;
  imageFields = [
    "avatar"
  ];
  checked = checkFields source (
    [
      "username"
      "git"
    ]
    ++ imageFields
  ) user;
  git = checkFields "${source}.git" [ "name" "email" ] (checked.git or { });
in
assert lib.all (
  field:
  let
    value = checked.${field} or null;
  in
  lib.assertMsg (
    value == null || (builtins.isPath value && builtins.pathExists value)
  ) "Host ${name}: ${source}.${field} must be an existing image path or null."
) imageFields;
assert lib.assertMsg
  (
    !(checked ? username)
    || (
      builtins.isString checked.username
      && builtins.match "[a-zA-Z_][a-zA-Z0-9_-]*[$]?" checked.username != null
    )
  )
  "Host ${name}: ${source}.username must be a valid account name (letters, digits, '_' or '-', starting with a letter or '_'; optional trailing '$').";
assert lib.assertMsg (
  !(git ? name) || nonEmptyText git.name
) "Host ${name}: ${source}.git.name must be a non-empty, single-line string.";
assert lib.assertMsg (
  !(git ? email) || nonEmptyText git.email
) "Host ${name}: ${source}.git.email must be a non-empty, single-line string.";
checked
