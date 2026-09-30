{ lib }:
let
  conflictCases = [
    {
      name = "two-login-managers";
      features = {
        gnome = true;
      };
      systemConfig.services.greetd.enable = true;
      message = "cannot both own the login screen";
    }
    {
      name = "two-system-ssh-agents";
      features = { };
      systemConfig.programs.ssh.startAgent = true;
      message = "Multiple SSH agents";
    }
    {
      name = "two-home-ssh-agents";
      features = { };
      homeConfig.services.ssh-agent.enable = true;
      homeAssertion = true;
      message = "cannot own the same user's SSH socket";
    }
    {
      name = "forced-gnome-agent";
      features.gnome = true;
      systemConfig = { lib, ... }: { services.gnome.gcr-ssh-agent.enable = lib.mkForce true; };
      message = "Multiple SSH agents";
    }
    {
      name = "disabled-compositor-dependency";
      features = {
        niri = true;
        dms = true;
      };
      systemConfig.programs.niri.enable = false;
      message = "Feature dms requires niri";
    }
    {
      name = "disabled-gpg-dependency";
      features = { };
      homeConfig.services.gpg-agent = {
        enable = false;
        enableSshSupport = true;
      };
      homeAssertion = true;
      message = "Feature gpgSshSupport requires gpg";
    }
  ];
in
conflictCases
