# Static built-in interfaces share one table. Interfaces with conditional
# demands or configuration logic live in their own adapter modules.
{
  imports = builtins.attrValues (
    builtins.mapAttrs
      (
        name: consumer:
        import ../../../software/consumer.nix (
          {
            scope = "home";
            id = "home-${name}";
            software = name;
            installedScopes = [ "home" ];
          }
          // consumer
        )
      )
      {
        chrome = {
          enableOptions = [
            [
              "programs"
              "google-chrome"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "google-chrome"
            "package"
          ];
          runtimePackageOption = [
            "programs"
            "google-chrome"
            "finalPackage"
          ];
        };
        ghostty = {
          enableOptions = [
            [
              "programs"
              "ghostty"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "ghostty"
            "package"
          ];
        };
        git = {
          enableOptions = [
            [
              "programs"
              "git"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "git"
            "package"
          ];
        };
        git-lfs = {
          enableOptions = [
            [
              "programs"
              "git"
              "enable"
            ]
            [
              "programs"
              "git"
              "lfs"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "git"
            "lfs"
            "package"
          ];
        };
        gnome-keyring = {
          installedScopes = [ ];
          enableOptions = [
            [
              "services"
              "gnome-keyring"
              "enable"
            ]
          ];
          packageOption = [
            "services"
            "gnome-keyring"
            "package"
          ];
        };
        nh = {
          enableOptions = [
            [
              "programs"
              "nh"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "nh"
            "package"
          ];
        };
        tela = {
          # Enabling GTK does not select a particular icon theme.
          requestWhenEnabled = false;
          enableOptions = [
            [
              "gtk"
              "enable"
            ]
          ];
          packageOption = [
            "gtk"
            "iconTheme"
            "package"
          ];
        };
        vim = {
          enableOptions = [
            [
              "programs"
              "vim"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "vim"
            "packageConfigurable"
          ];
          runtimePackageOption = [
            "programs"
            "vim"
            "package"
          ];
        };
        vscode = {
          enableOptions = [
            [
              "programs"
              "vscode"
              "enable"
            ]
          ];
          packageOption = [
            "programs"
            "vscode"
            "package"
          ];
        };
        xdg-terminal-exec = {
          enableOptions = [
            [
              "xdg"
              "terminal-exec"
              "enable"
            ]
          ];
          packageOption = [
            "xdg"
            "terminal-exec"
            "package"
          ];
        };
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
      }
  );
}
