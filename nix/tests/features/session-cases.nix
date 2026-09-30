{ lib }:
let
  desktopCases = [
    {
      name = "console";
      features = { };
      desktop = null;
      loginManager = "none";
    }
    {
      name = "gnome";
      features = {
        gnome = true;
        chinese = true;
      };
      desktop = "gnome";
      loginManager = "gdm";
    }
    {
      name = "niri";
      features.niri = true;
      desktop = "niri";
      loginManager = "greetd";
    }
    {
      name = "niri-dms";
      features = {
        niri = true;
        dms = true;
        chinese = true;
      };
      desktop = "niri";
      loginManager = "greetd";
    }
    {
      name = "gnome-manual-login";
      features.gnome = true;
      systemConfig.services.displayManager.gdm.enable = false;
      desktop = "gnome";
      loginManager = "none";
    }
  ]
  ++
    lib.concatMap
      (
        dms:
        map
          (desktop: {
            name = "both-${if dms then "dms" else "bare"}-${if desktop == null then "default" else desktop}";
            features = {
              gnome = true;
              niri = true;
              inherit dms;
              chinese = true;
            };
            preferences = lib.optionalAttrs (desktop != null) { inherit desktop; };
            desktop = if desktop == null then "niri" else desktop;
            loginManager = if desktop == "gnome" then "gdm" else "greetd";
          })
          [
            null
            "gnome"
            "niri"
          ]
      )
      [
        false
        true
      ];
  agentCases =
    map
      (state: {
        name = "gnome-gpg-${state.name}";
        features = {
          gnome = true;
          gpg = state.gpg;
        }
        // lib.optionalAttrs (state ? ssh) { gpgSshSupport = state.ssh; };
        desktop = "gnome";
        loginManager = "gdm";
        gpg = state.gpg;
        ssh = state.ssh or false;
      })
      [
        {
          name = "disabled";
          gpg = false;
          ssh = false;
        }
        {
          name = "no-ssh";
          gpg = true;
          ssh = false;
        }
      ];
  cases =
    desktopCases
    ++ agentCases
    ++ [
      {
        name = "smartcard-without-gpg";
        features.gpg = false;
        features.gpgSshSupport = false;
        desktop = null;
        loginManager = "none";
        gpg = false;
        ssh = false;
      }
      {
        name = "gpg-without-smartcard";
        features.smartcard = false;
        desktop = null;
        loginManager = "none";
      }
    ];
in
cases
