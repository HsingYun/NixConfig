let
  all = [
    "linux"
    "nixos"
    "nixos-wsl"
    "darwin"
  ];
  linux = [
    "linux"
    "nixos"
    "nixos-wsl"
  ];
  nixos = [
    "nixos"
    "nixos-wsl"
  ];
in
{
  features = {
    plymouth = {
      platforms = [ "nixos" ];
      systemModules = [ ../../modules/system/features/plymouth.nix ];
    };
    network = {
      default = true;
      platforms = [ "nixos" ];
      systemModules = [ ../../modules/system/features/network.nix ];
    };
    xdg = {
      default = true;
      platforms = linux;
      homeModules = [ ../../modules/home/features/xdg.nix ];
    };
    git = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/git.nix ];
    };
    shell = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/shell.nix ];
      systemModules = [ ../../modules/system/features/shell.nix ];
    };
    gpg = {
      default = true;
      platforms = all;
      activation = {
        scope = "home";
        option = [
          "services"
          "gpg-agent"
          "enable"
        ];
      };
      homeModules = [ ../../modules/home/features/gpg.nix ];
    };
    gpgSshSupport = {
      default = true;
      platforms = all;
      requires = [ "gpg" ];
      homeModules = [ ../../modules/home/features/gpg-ssh.nix ];
      activation = {
        scope = "home";
        option = [
          "services"
          "gpg-agent"
          "enableSshSupport"
        ];
      };
    };
    nixTools = {
      default = true;
      platforms = all;
      homeModules = [ ../../modules/home/features/nix-tools.nix ];
    };
    devel = {
      platforms = all;
      homeModules = [ ../../modules/home/features/devel.nix ];
    };
    smartcard = {
      default = true;
      platforms = nixos;
      systemModules = [ ../../modules/system/features/smartcard.nix ];
    };
    nixLd = {
      default = true;
      platforms = nixos;
      systemModules = [ ../../modules/system/features/nix-ld.nix ];
    };
    gnome = {
      platforms = [ "nixos" ];
      homeModules = [ ../../modules/home/features/gnome.nix ];
      systemModules = [ ../../modules/system/features/gnome.nix ];
    };
    niri = {
      activation = {
        scope = "system";
        option = [
          "programs"
          "niri"
          "enable"
        ];
      };
      platforms = [ "nixos" ];
      homeModules = [ ../../modules/home/features/niri.nix ];
      systemModules = [ ../../modules/system/features/niri.nix ];
    };
    dms = {
      activation = {
        scope = "system";
        option = [
          "programs"
          "dms-shell"
          "enable"
        ];
      };
      platforms = [ "nixos" ];
      requires = [ "niri" ];
      homeModules = [ ../../modules/home/features/dms.nix ];
      systemModules = [ ../../modules/system/features/dms.nix ];
    };
    ghostty = {
      platforms = linux;
      homeModules = [ ../../modules/home/features/ghostty.nix ];
    };
    mpv = {
      platforms = all;
      homeModules = [ ../../modules/home/features/mpv.nix ];
    };
    chinese = {
      platforms = linux;
      homeModules = [ ../../modules/home/features/chinese.nix ];
      systemPlatforms = nixos;
      systemModules = [ ../../modules/system/features/chinese.nix ];
    };
  };

  choices = {
    desktop = {
      providers = {
        gnome = "gnome";
        niri = "niri";
      };
      empty = null;
    };
    loginManager = {
      providers = {
        gdm = "gnome";
        dms = "dms";
      };
      empty = "none";
      alternatives = [ "none" ];
    };
  };

  integrations = {
    gpg-smartcard = {
      platforms = nixos;
      owners = [
        "gpg"
        "gpgSshSupport"
      ];
      homeModules = [ ../../modules/integrations/smartcard.nix ];
    };
    gnome-chinese = {
      platforms = [ "nixos" ];
      owners = [ "chinese" ];
      homeModules = [ ../../modules/integrations/gnome-chinese.nix ];
    };
    niri-dms = {
      platforms = [ "nixos" ];
      owners = [ "niri" ];
      homeModules = [ ../../modules/integrations/niri-dms.nix ];
    };
  };
}
