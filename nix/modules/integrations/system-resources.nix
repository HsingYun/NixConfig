{ selected, enabled }:

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
  desktop =
    if selected.desktop != null then
      selected.desktop
    else if enabled.dms then
      "niri"
    else
      null;
  useDmsGreeter = enabled.dms && desktop == "niri";
  sessionCommand =
    if desktop == "gnome" then
      "env XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=GNOME ${pkgs.gnome-session}/bin/gnome-session --session=gnome"
    else
      "niri-session";
  managesSsh = enabled.gpg || enabled.gpgSshSupport || enabled.gnome;
in
{
  services.displayManager = {
    defaultSession = lib.mkIf (desktop != null) desktop;
    gdm.enable = lib.mkIf enabled.gnome (lib.mkDefault (selected.loginManager == "gdm"));
    dms-greeter = {
      package = lib.mkIf (useDmsGreeter && selected.loginManager == "greetd") (
        lib.mkDefault (
          import ../../assets/helpers/greeter-session.nix { inherit lib pkgs; } {
            command = "${pkgs.dms-greeter}/bin/dms-greeter";
            cacheDir = "/var/lib/dms-greeter";
            inherit desktop;
          }
        )
      );
      enable = lib.mkIf enabled.dms (lib.mkDefault (useDmsGreeter && selected.loginManager == "greetd"));
      compositor.name = lib.mkIf (useDmsGreeter && selected.loginManager == "greetd") (
        lib.mkDefault "niri"
      );
    };
  };

  services.greetd = lib.mkIf ((enabled.niri || enabled.gnome) && !useDmsGreeter) {
    enable = lib.mkDefault (selected.loginManager == "greetd");
    settings.default_session = lib.mkIf (selected.loginManager == "greetd") {
      command = "${lib.getExe pkgs.tuigreet} --time --cmd ${lib.escapeShellArg sessionCommand}";
      user = "greeter";
    };
  };

  services.gnome.gcr-ssh-agent.enable = lib.mkIf (managesSsh && (gpgSsh || otherSsh)) false;

  # Home Manager owns the daemon; NixOS supplies PAM, DBus and portal support.
  services.gnome.gnome-keyring.enable = lib.mkIf (
    enabled.gnome || enabled.niri || enabled.dms || home.features.desktop.keyring.enable
  ) (lib.mkOverride 900 home.features.desktop.keyring.enable);

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
