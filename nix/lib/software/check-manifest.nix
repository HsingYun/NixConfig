{ lib }:
{
  provider,
  requested,
  actual,
}:
lib.mapAttrsToList (group: names: {
  assertion = lib.all (name: builtins.elem name (actual.${group} or [ ])) names;
  message = "Software: ${provider}.${group} drops requested installations. Change software requirements or provider selection instead of overriding the assembled manifest.";
}) requested
