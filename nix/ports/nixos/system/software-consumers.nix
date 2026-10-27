{ ... }: {
  imports = builtins.attrValues (
    builtins.mapAttrs
      (
        name: consumer:
        import ../../../modules/software/consumer.nix (
          {
            scope = "system";
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
          enableOptions = [
            [
              "programs"
              "dux-shell"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "dux-shell"
            "package"
          ];
        };
        noctalia = {
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
