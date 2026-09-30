{ ... }: {
  imports = builtins.attrValues (
    builtins.mapAttrs
      (
        name: consumer:
        import ../../../modules/software/consumer.nix (
          {
            id = "system-${name}";
            software = name;
            installedScopes = [ "system" ];
          }
          // consumer
        )
      )
      {
        zsh = {
          enableOptions = [
            [
              "programs"
              "zsh"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "zsh"
            "package"
          ];
        };
        dms = {
          requestWhenEnabled = true;
          enableOptions = [
            [
              "programs"
              "dms-shell"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "dms-shell"
            "package"
          ];
        };
        noctalia = {
          requestWhenEnabled = true;
          enableOptions = [
            [
              "programs"
              "noctalia"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "noctalia"
            "package"
          ];
        };
        noctalia-greeter = {
          requestWhenEnabled = true;
          enableOptions = [
            [
              "services"
              "displayManager"
              "noctalia-greeter"
              "enable"
            ]
          ];
          packageOption = [
            "services"
            "displayManager"
            "noctalia-greeter"
            "package"
          ];
        };
      }
  );
}
