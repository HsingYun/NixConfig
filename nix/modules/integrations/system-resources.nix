{ desktopSession, enabled }:

{
  config,
  lib,
  user,
  pkgs,
  ...
}:

let
  home = config.home-manager.users.${user.username};
  gpgSsh = home.services.gpg-agent.enable && home.services.gpg-agent.enableSshSupport;
  otherSsh = home.services.ssh-agent.enable || config.programs.ssh.startAgent;
  sshAgents = [
    gpgSsh
    home.services.ssh-agent.enable
    config.programs.ssh.startAgent
    config.services.gnome.gcr-ssh-agent.enable
  ];
  inherit (desktopSession) desktop loginManager;
  useDmsGreeter = desktopSession.greeter == "dms-greeter";
  sessionCommand = desktopSession.command {
    gnomeSession = "${pkgs.gnome-session}/bin/gnome-session";
  };
  managesSsh = enabled.gpg || enabled.gpgSshSupport || enabled.gnome;
in
{
  services = {
    displayManager = {
      defaultSession = lib.mkIf (desktop != null) desktop;
      gdm.enable = lib.mkIf enabled.gnome (lib.mkDefault (loginManager == "gdm"));
      dms-greeter = {
        package = lib.mkIf useDmsGreeter (
          lib.mkDefault (
            import ../../assets/helpers/greeter-session.nix { inherit lib pkgs; } {
              command = "${pkgs.dms-greeter}/bin/dms-greeter";
              cacheDir = "/var/lib/dms-greeter";
              inherit desktop;
            }
          )
        );
        enable = lib.mkIf enabled.dms (lib.mkDefault useDmsGreeter);
        compositor.name = lib.mkIf useDmsGreeter (lib.mkDefault "niri");
      };
    };
    greetd = lib.mkIf ((enabled.niri || enabled.gnome) && !useDmsGreeter) {
      enable = lib.mkDefault (loginManager == "greetd");
      settings.default_session = lib.mkIf (loginManager == "greetd") {
        command = "${lib.getExe pkgs.tuigreet} --time --cmd ${lib.escapeShellArg sessionCommand}";
        user = "greeter";
      };
    };
    # Home Manager owns the daemon; NixOS supplies PAM, DBus and portal support.
    gnome = {
      gcr-ssh-agent.enable = lib.mkIf (managesSsh && (gpgSsh || otherSsh)) false;
      gnome-keyring.enable = lib.mkIf (
        enabled.gnome || enabled.niri || enabled.dms || home.features.desktop.keyring.enable
      ) (lib.mkOverride 900 home.features.desktop.keyring.enable);
    };
  };

  security.pam.services = lib.mkIf (
    config.services.greetd.enable && home.features.desktop.keyring.enable
  ) { greetd.enableGnomeKeyring = lib.mkDefault true; };

  assertions =
    lib.optionals (enabled.gnome || enabled.niri || enabled.dms) [
      {
        assertion = !(config.services.displayManager.gdm.enable && config.services.greetd.enable);
        message = "GDM and greetd (including DMS greeter) cannot both own the login screen. Select preferences.loginManager and remove conflicting system overrides.";
      }
    ]
    ++ lib.optionals managesSsh [
      {
        assertion = lib.count (enabled: enabled) sshAgents <= 1;
        message = "Multiple SSH agents are configured for the managed user. Select one of GPG SSH support, the Home Manager SSH agent, the system SSH agent, or GNOME GCR.";
      }
    ];
}
