{ ... }:
{
  imports = builtins.attrValues (
    builtins.mapAttrs (
      name: consumer:
      import ../../software/consumer.nix (
        {
          id = "home-${name}";
          software = name;
        }
        // consumer
      )
    ) (import ./package-options.nix)
  );
}
